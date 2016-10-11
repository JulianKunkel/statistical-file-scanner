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

# We have two tables, one containing file names and how often they have been chosen
# One containing the scanning results for each file and each chunk of data (by default 1 GiB of data)

con = dbConnect(SQLite(), dbname="results.db")
f = dbGetQuery(con,'select * from f where size <= 4096' )
printf("Files smaller than 4 KiB in the database: %.0f", nrow(f))

f = dbGetQuery(con,'select * from f where size > 4096' )

# print what we have scanned

printf("Database contains: %.0f files %.1f GiB; selection count: %.0f size: %.1f GiB, max selections of one file: %.0f)", nrow(f), sum(f$size) / GiB, sum(f$chosen), sum(f$chosen * f$size) / GiB, max(f$chosen))
print(table(f$cdotype))
print(table(f$project))

# print file sizes

f$sizelog = log10(f$size)
ggplot(f, aes(cdotype, sizelog)) +  geom_boxplot() + ylab("size (log10) byte")
ggsave("scanned-size-cdotype.png")

ggplot(f, aes(1, sizelog)) +  geom_boxplot() + ylab("size (log10) byte") + xlab("")
ggsave("scanned-size.png")

spng("scanned-sizes-log10")
hist((log10(f$size)), ylab="Frequency", xlab="Files size", xaxt="n", nclass=15, main="")
axis(side = 1, at=(1:13), labels=c("10", "100", "1k", "10k", "100k", "1M", "10M",  "100M", "1G", "10G", "100G", "1T", "10T"))
grid(col="gray")
dev.off()


# determine compressors

o = dbGetQuery(con,'select * from p limit 1' )
# identify the methods provided in the database
compressors = colnames(o)[3:ncol(o)]
compressors = unique(substr(compressors,3,nchar(compressors)))

print(paste("Compressor available: ", compressors, sep=" "))

# Now work on the full table

r = dbGetQuery(con,'select * from p join f on p.fid == f.fid' )

r$filetype = as.factor(r$filetype)
r$cdotype = as.factor(r$cdotype)

### Plotting filetype graph

plottype = function(tbl, name){
  tbl = tbl[ order(tbl$count, decreasing=TRUE), ]
  print(tbl)

  cols2 = c("lightblue", "red", "lightgreen", "orange", "gray", "brown")

  spng(name, width=2, height=4)
  x = barplot(as.matrix(tbl),col=cols2, main="", ylab="%")
  ts = cumsum(tbl$size)
  tc = cumsum(tbl$count)
  olds = 0
  oldc = 0
  for (v in 1:nrow(tbl)){
    delta = tbl$size[v]
    if( delta > 4){
      text(x[1], (olds + ts[v])/2, substr(rownames(tbl)[v],0,18))
    }
    delta = tbl$count[v]
    if( delta > 4){
      text(x[2], (oldc + tc[v])/2, substr(rownames(tbl)[v],0,18))
    }
    olds = ts[v]
    oldc = tc[v]
  }
  dev.off()
}

r.size = sum(r$size)
r.count = nrow(r)
tbl = ddply(r,~filetype, summarise, size=sum(size)/r.size*100,count=length(filetype)/r.count*100)
rownames(tbl) = tbl$filetype
tbl$filetype = NULL
plottype(tbl, "scanned-filetype")

tbl = ddply(r,~cdotype,summarise,size=sum(size)/r.size*100,count=length(cdotype)/r.count*100)
rownames(tbl) = tbl$cdotype
tbl$cdotype = NULL
plottype(tbl, "scanned-cdotype")


tbl = dbGetQuery(con,'select filetype, sum(f.chosen*f.size) as size, sum(f.chosen) as count from f group by filetype' )
tbl$count = tbl$count / sum(tbl$count) * 100
tbl$size = tbl$size / sum(tbl$size) * 100
rownames(tbl) = tbl$filetype
tbl$filetype = NULL
plottype(tbl, "selected-filetype")

tbl = dbGetQuery(con,'select cdotype, sum(f.chosen*f.size) as size, sum(f.chosen) as count from f group by cdotype' )
tbl$count = tbl$count / sum(tbl$count) * 100
tbl$size = tbl$size / sum(tbl$size) * 100
rownames(tbl) = tbl$cdotype
tbl$cdotype = NULL
plottype(tbl, "selected-cdotype")


######

for (C in compressors ){
    size = r[, sprintf("ss%s", C)]
    r[, sprintf("ratio_%s", C)] = r[, sprintf("sc%s", C)] / size
    r[, sprintf("rcMiBs_%s", C)] = size / r[, sprintf("tt%s", C)] / MiB * 1e9
    r[, sprintf("rdMiBs_%s", C)] = size / r[, sprintf("td%s", C)] / MiB * 1e9
    # be careful rdMiBs is sometimes 0 !
}


meanStatistics <- function(r, compressors) {
  tbl = data.frame(compressors)
  tbl$ratioCount = 0
  tbl$ratioSize = 0
  tbl$Compress_MiBpros = 0
  tbl$Decompress_MiBpros = 0
  for (C in compressors ){
    what = c("fid", sprintf("ratio_%s", C), sprintf("tt%s", C), sprintf("td%s", C), sprintf("ss%s", C), sprintf("sc%s", C))
    if ( C == "memcpy"){
      t = r[ r$pos == 0 , what]
    }else{
      t = r[ r[, sprintf("td%s", C)]  != 0, what  ]
    }
    colnames(t) = c("fid", "ratio", "tt", "td", "ss", "sc")
    b = ddply(t,~fid,summarise,size=sum(ss), sc=sum(sc))
    # * t$chosen

    tbl$ratioCount[which(tbl$compressors == C)] = mean(b$sc / b$size)
    tbl$ratioSize[which(tbl$compressors == C)] = sum(t$sc) / sum(t$ss)
    tbl$Compress_MiBprosHam[which(tbl$compressors == C)] = sum(t$ss) / sum(t$tt) / MiB * 1e9
    tbl$Decompress_MiBprosHam[which(tbl$compressors == C)] = sum(t$ss) / sum(t$td) / MiB * 1e9
    tbl$Compress_MiBpros[which(tbl$compressors == C)] = (1/mean(t$tt/t$ss)) / MiB * 1e9
    tbl$Decompress_MiBpros[which(tbl$compressors == C)] = (1/mean(t$td/t$ss)) / MiB * 1e9
    tbl$Compress_MiBprosH[which(tbl$compressors == C)] = mean(t$ss/t$tt) / MiB * 1e9
    tbl$Decompress_MiBprosH[which(tbl$compressors == C)] = mean(t$ss/t$td) / MiB * 1e9
  }
  rownames(tbl) = tbl$compressors
  tbl$compressors = NULL
  t = NULL
  return(tbl)
}


tbl = meanStatistics(r, compressors)
write.csv(tbl, file = "statistics.csv")

remove = c()

## identify those that are superior
m = matrix(nrow=nrow(tbl), ncol=nrow(tbl))
for (i in 1:nrow(tbl)){
  c = tbl[i,]
  for (j in 1:nrow(tbl)){
    k = tbl[j,]
    if (k$ratioCount > c$ratioCount && k$ratioSize > c$ratioSize && k$Compress_MiBpros < c$Compress_MiBpros &&  k$Decompress_MiBpros < c$Decompress_MiBpros){
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
