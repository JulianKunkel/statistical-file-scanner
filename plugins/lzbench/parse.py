import re

lzbenchRe = re.compile("([^,]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)")

def extractCDOType(lines):
    merged = "".join(lines)
    if (re.search("cdo filedes: Open failed on", merged)):
        return "unknown"
    # TODO: filter irrelevant information better to avoid costly postprocessing
    return merged.replace("\n", ",").strip(",")

def parseType(typ):
    if typ.startswith("gzip compressed data"):
        return "gzip"
    m = re.match("(.* data) \([^)]*\)", typ)
    if m:
        typ = m.group(1)
    m = re.match("(.*) \([^)]* records\)", typ)
    if m:
        typ = m.group(1)
    typ = typ.split(",")[0].split("-")[0].strip()
    if re.search(" text", typ) or typ.startswith("FORTRAN program") or typ.startswith("Bourne") or typ.startswith("a /usr/bin/"):
        return "text"
    if re.search(" executable", typ) or typ.startswith("ELF "):
        return "executable"
    if re.search("image", typ):
        return "image"
    return typ

def parseCDOType(typ):
    m = re.match("Processed (\d+) variable[^\n]*\n(.*) data.*", typ, re.MULTILINE)
    if m:
        return m.group(2).strip()
    return "unknown"

def identifyVerbs(files):
  verbs = {}
  for fname in files:
      try:
        f = open(fname, 'r', encoding="latin-1")
        parse = False
        for line in f:
            m = lzbenchRe.match(line)
            if (m):
              if line.find("/") != -1: # skip wrong lines
                  continue
              verb = m.group(1)
              if verb not in verbs:
                verbs[verb] = 0
              verbs[verb] = verbs[verb] + 1
        f.close()
      except FileNotFoundError as err:
        print("Could not open: " + fname)
  return verbs


def cleanVerb(verb):
    if type(verb) == list:
        return  [ x.replace(" ", "").replace(".", "").replace("-","_") for x in verb ]
    else:
        return  verb.replace(" ", "").replace(".", "").replace("-","_")

def parseLZbench(txt, filename):
    pos = 0
    data = {"pos": 0}
    dataArray = []
    error = False
    for l in txt:
        m = lzbenchRe.match(l)
        if m:
          c = cleanVerb(m.group(1))
          if ("tt" + c) in data:
            if not error:
                dataArray.append(data)
            pos = pos + 1
            data = { "pos" : pos, "ttmemcpy": 0, "tdmemcpy": 0, "ssmemcpy": 0, "scmemcpy": 0 }

          data["tt" + c] = float(m.group(2))
          data["td" + c] = float(m.group(3))
          data["ss" + c] = float(m.group(4))
          data["sc" + c] = float(m.group(5))

          #if float(m.group(3)) == 0:
              #print("Compressor %s failed in file %s, ignoring" % (c, filename))
              #error = True
    if not error:
        dataArray.append(data)
    return dataArray

class dataParser():
    verbs = ""
    re = re.compile("File types\n([^\n]*)\n.*cdo filedes: (.*)\nStarting RUN\n(.*)\n", re.MULTILINE | re.DOTALL)

    def parse(self, txt, fileData):
        txt = "".join(txt)
        m = self.re.match(txt)
        data = [{},{}]
        if m:
            ft = m.group(1)
            cdo = m.group(2)
            data[1] = parseLZbench(m.group(3).split("\n"), fileData["file"])
            data[0]["completefiletype"] = ft
            data[0]["filetype"] = parseType(ft)
            data[0]["completecdotype"] = extractCDOType(cdo)
            data[0]["cdotype"] = parseCDOType(cdo)
        return data


    def tokensFile(self, files):
        return [("filetype", "text"), ("cdotype", "text"), ("completefiletype", "text"), ("completecdotype", "text")]

    def tokensBlock(self, files):
        verbs = identifyVerbs(files)
        #for v in verbs:
        #  print(v + ": " + str(verbs[v]))
        #mn = min(verbs.values())
        #print(mn)
        verbs = verbs.keys();

        allVerbs = ["pos"]
        # time compression:
        allVerbs.extend( [ "tt" + x for x in verbs] )
        # time decompression:
        allVerbs.extend( [ "td" + x for x in verbs] )
        # size:
        allVerbs.extend( [ "ss" + x for x in verbs] )
        # size compressed:
        allVerbs.extend( [ "sc" + x for x in verbs] )
        verbs = allVerbs
        self.verbscleaned = [ cleanVerb(x) for x in verbs]
        a = [ (x, "real") for x in self.verbscleaned ]
        return a
