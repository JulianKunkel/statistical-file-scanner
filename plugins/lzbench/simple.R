#!/usr/bin/env Rscript
library(sqldf)
library(ggplot2)
library(plyr)

MiB = 1024*1024
GiB = MiB * 1024

printf <- function(...) invisible(print(sprintf(...)))
spng = function(name, width=4, height=2.5){
 png(  sprintf("%s.png",name),  width  = width,  height = height,  units     = "in",  res       = 600,  pointsize = 4)
 par(  mar      = c(15, 5, 2, 2),  xaxs     = "i",  yaxs     = "i",  cex.axis = 2,  cex.lab  = 2)#, cex.text = 2)
}


con = dbConnect(SQLite(), dbname="results.db")
f = dbGetQuery(con,'select * from f where size > 4096' )

printf("%.0f files %.1f GiB", nrow(f), sum(f$size) / GiB)
print(table(f$cdotype))
print(table(f$project))

f$sizelog = log10(f$size)
ggplot(f, aes(cdotype, sizelog)) +  geom_boxplot() + ylab("size (log10) byte")
ggsave("size-cdotype.png")

ggplot(f, aes(1, sizelog)) +  geom_boxplot() + ylab("size (log10) byte") + xlab("")
ggsave("size.png")

spng("sizes-log10")
hist((log10(f$size)), ylab="Frequency", xlab="Files size", xaxt="n", nclass=15, main="")
axis(side = 1, at=(1:13), labels=c("10", "100", "1k", "10k", "100k", "1M", "10M",  "100M", "1G", "10G", "100G", "1T", "10T"))
grid(col="gray")
dev.off()

# full table

o = dbGetQuery(con,'select * from p limit 1' )
# identify the methods provided in the database
compressors = colnames(o)[3:ncol(o)]
compressors = unique(substr(compressors,3,nchar(compressors)))

r = dbGetQuery(con,'select * from p join f on p.fid == f.fid' )

r$filetype = as.factor(r$filetype)
r$cdotype = as.factor(r$cdotype)

### plotting filetype graph
plottype = function(tbl, name){
  tbl = tbl[ order(tbl$count, decreasing=TRUE), ]
  tbl$filetype = as.ordered(tbl$filetype)

  r.countChosen = sum(tbl$count)
  tbl$count = tbl$count / r.countChosen*100
  ggplot(tbl, aes(x=filetype, y=count, fill=count)) + geom_bar(stat="identity") + ylab("Estimated % of total occupied size") +  scale_x_discrete(limits = tbl$filetype) + scale_fill_gradientn(colours = rainbow(3))
  ggsave(paste(name, "-all.png", sep=""))

  rownames(tbl) = tbl$filetype
  tbl$filetype = NULL

  cols2 = c("lightblue", "red", "lightgreen", "orange", "gray", "brown")
  print(tbl)

  spng(name, width=1.8, height=2.9)
  x = barplot(as.matrix(tbl),col=cols2, main="", ylab="%", xlab="")

  tc = cumsum(tbl$count)
  oldc = 0
  for (v in 1:nrow(tbl)){
    delta = tbl$count[v]
    if( delta > 4){
      text(x[1], (oldc + tc[v])/2, substr(rownames(tbl)[v],0,18))
    }
    oldc = tc[v]
  }
  dev.off()
}

tbl = dbGetQuery(con,'select filetype, sum(chosen) as count from f chosen group by filetype' )
plottype(tbl, "filetypeChosen")

tbl = dbGetQuery(con,'select cdotype as filetype, sum(chosen) as count from f chosen group by cdotype' )
plottype(tbl, "cdotypeChosen")

######

for (C in compressors ){
    size = r[, sprintf("ss%s", C)]
    r[, sprintf("ratio_%s", C)] = r[, sprintf("sc%s", C)] / size
    r[, sprintf("rcMiBs_%s", C)] = size / r[, sprintf("tt%s", C)] / MiB * 1e9
    r[, sprintf("rdMiBs_%s", C)] = size / r[, sprintf("td%s", C)] / MiB * 1e9
    # be careful rdMiBs is sometimes 0 !
}


meanStatistics <- function(compressors) {
  tbl = data.frame(compressors)
  tbl$ratio = NA
  tbl$compressMiB = NA
  tbl$decompressMiB = NA

  for (C in compressors ){
    # select cdotype as filetype, sum(ttmemcpy*chosen) as tt, sum(tdmemcpy*chosen) as td, sum(scmemcpy*chosen)/sum(ssmemcpy*chosen) as ratio, f.chosen as chosen  from f join p on f.fid = p.fid group by cdotype;

    # Summarize the values for each file:
    r = dbGetQuery(con, sprintf('select cdotype as filetype, project, sum(tt%s) as tt, sum(td%s) as td, sum(sc%s)/sum(ss%s) as ratio, ss%s as size, sc%s as sc, f.chosen as chosen  from f join p on f.fid = p.fid group by p.fid', C, C, C, C, C, C))

    # Compute the mean based on the counts
    #b = ddply(t,~fid,summarise,size=sum(ss), sc=sum(sc))
    sum_chosen = sum(r$chosen)
    tbl$ratio[which(tbl$compressors == C)] = sum(r$ratio * r$chosen) / sum_chosen

    tbl$compressMiB[which(tbl$compressors == C)] = sum(r$size / r$tt * r$chosen) / sum_chosen  / MiB * 1e6
    tbl$decompressMiB[which(tbl$compressors == C)] = sum(r$size / r$td * r$chosen) / sum_chosen  / MiB * 1e6

    # Normal computation THAT IS WRONG WITH THE STATISTICAL APPROACH
    tbl$ratioWrongNormalMean[which(tbl$compressors == C)] = mean(r$ratio)
    tbl$compressMiBWrongNormalMean[which(tbl$compressors == C)] = mean(r$size / r$tt ) / MiB * 1e6
    tbl$decompressMiBWrongNormalMean[which(tbl$compressors == C)] = mean(r$size / r$td)  / MiB * 1e6
  }
  rownames(tbl) = tbl$compressors
  tbl$compressors = NULL
  r = NULL
  return(tbl)
}


# Write out the average statistics
tbl = meanStatistics(compressors)
write.csv(tbl, file = "statistics.csv")

remove = c()

## identify those that are superior
m = matrix(nrow=nrow(tbl), ncol=nrow(tbl))
for (i in 1:nrow(tbl)){
  c = tbl[i,]
  for (j in 1:nrow(tbl)){
    k = tbl[j,]
    if (k$ratio > c$ratio && k$compressMiB < c$compressMiB &&  k$decompressMiB < c$decompressMiB){
      m[i,j] = 1
      remove = c(remove, j)
    }else{
      m[i,j] = 0
    }
  }
}
purge = rownames(tbl)[unique(remove)]
compressors.afterPurge = compressors[!(compressors %in% purge)]

tbl.afterPurge = tbl[ rownames(tbl) %in% compressors.afterPurge,]
write.csv(tbl.afterPurge, file = "statistics-afterPurge.csv")

# Remove transitive links
for (i in 1:nrow(tbl)){
  for (j in 1:nrow(tbl)){ # j is better
    if (m[i,j] == 1){
      for (k in 1:nrow(tbl)){
        if (m[j, k] == 1 && m[i,k] == 1){
          m[i,k] = 0;
        }
      }
    }
  }
}

sink(file = "better-avg.dot")
cat("#dot -Tpng better-avg.dot > better-avg.png\n")
cat("digraph averageBetter{\n")
for (i in 1:nrow(tbl)){
  for (j in 1:nrow(tbl)){
    if (m[i,j] == 1){
      cat(sprintf("%s -> %s;\n", rownames(tbl)[i], rownames(tbl)[j] ))
    }
  }
}
cat("}\n")
sink()
