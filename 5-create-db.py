#!/usr/bin/env python3
import sys
import re
import sqlite3
import traceback
import imp
import os

__version = "0.9"
__license__ = "GPL"
__author__ = "Julian Kunkel"
__date__ = "2016"

debugging = False
debugging = True

if len(sys.argv) < 3:
    print("Synopsis: <module> <prefixToProjectDir> <files>")
    sys.exit(1)

module = sys.argv[1]
prefix = sys.argv[2]
files = sys.argv[3:]

def load_module_from_file(filepath): # see http://stackoverflow.com/questions/301134/dynamic-module-import-in-python
    class_inst = None
    expected_class = 'dataParser'

    mod_name,file_ext = os.path.splitext(os.path.split(filepath)[-1])
    if file_ext.lower() == '.py':
        py_mod = imp.load_source(mod_name, filepath)
    elif file_ext.lower() == '.pyc':
        py_mod = imp.load_compiled(mod_name, filepath)
    if hasattr(py_mod, expected_class):
        class_inst = getattr(py_mod, expected_class)()
    return class_inst


def debug(str):
    global debugging
    if debugging:
        print(str)

def debugTrace():
    global debugging
    if debugging:
        traceback.print_exc()

global insertedTuples
global insertedFiles

parser = load_module_from_file(module)
tokensBlock = parser.tokensBlock(files)
tokensFile = parser.tokensFile(files)

keysBlock = [ x[0] for x in tokensBlock]
keysFile = [ x[0] for x in tokensFile]

conn = sqlite3.connect('results.db')
conn.text_factory = str


print("Database schema:")
try:
    tbl = "CREATE TABLE p (fid int"
    for (name, typ) in tokensBlock:
        tbl = tbl + ", " + name + " " + typ
    tbl = tbl + ")"
    debug(tbl)
    conn.execute(tbl)

    tbl = "CREATE TABLE f (fid int, chosen int, thread int, file text UNIQUE, project text, size real"
    for (name, typ) in tokensFile:
        tbl = tbl + ", " + name + " " + typ
    tbl = tbl + ")"

    debug(tbl)
    conn.execute(tbl)
except:
  print("Error creating db: " + tbl)

print()


def insertFile(data, bufferedLines):
  global keysFile
  global insertedFiles
  (fileTuples, dataTuples) = parser.parse(bufferedLines, data)
  data.update(fileTuples)

  expected = set(["fid", "chosen",  "thread", "file", "project", "size"] + keysFile)

  diff = expected.difference(set(data.keys()))
  if len(diff) == 0:
    # check if it exists
    sql = 'select fid from f where file = "%s"' % (data["file"])
    try:
        fid = conn.execute(sql, data).fetchone()[0]
        insertTuple(dataTuples, fid)
        return
    except:
        pass

    columns = ", ".join(expected)
    placeholders = ':' + ', :'.join(expected)
    sql = 'INSERT INTO f (%s) VALUES (%s)' % (columns, placeholders)
    try:
        conn.execute(sql, data)
        insertedFiles = insertedFiles + 1
        insertTuple(dataTuples, insertedFiles - 1)
    except:
        debugTrace()
        debug("Error while inserting sql " + sql)
    # debug(data["file"] + " " + str(data["size"]))
  elif (len(data) > 0):
    debug("Error while processing data expected " + str(len(expected)) + " received " + str(len(data)) + " keys")
    for key in data:
        debug("\t %s = %s " % (key,data[key]))
    debug("Missing: " + str(diff))


def insertTuple(dataArray, fileNumber):
  global insertedTuples
  global keysBlock
  expected = set(["fid"] + keysBlock)

  for data in dataArray:
      data["fid"] = fileNumber
      diff = expected.difference(set(data.keys()))

      if len(diff) == 0:
        columns = ", ".join(expected)
        placeholders = ':' + ', :'.join(expected)
        sql = 'INSERT INTO p (%s) VALUES (%s)' % (columns, placeholders)
        try:
            conn.execute(sql, data)
            insertedTuples = insertedTuples + 1
        except:
          debugTrace()
          print("Error while inserting sql " + sql)
      elif (len(data) > 0):
        debug("Error while processing data expected " + str(len(expected)) + " received " + str(len(data)) + " keys")
        for key in data:
            debug("\t %s = %s " % (key,data[key]))
        debug("Missing: " + str(diff))

def parse(args, parser, prefix):
    global insertedTuples
    global insertedFiles
    insertedFiles = conn.execute("select count(*) as count from f").fetchone()[0] + 1

    projectRe = re.compile("Processing: ([0-9]+) (" + prefix + "(/[^/]*/).*)") # the first directory
    alreadyRe = re.compile("Already processed: (.*)")

    insertedTuples = 0
    num = 0
    bufferedLines = []
    for fname in args:
        lastFiles = insertedFiles
        lastTuples = insertedTuples
        print("Processing file: " + fname)
        bufferedLines = []
        try:
            m = re.match("thread-output-(.*)([0-9]+)", fname)
            if m:
                thread = m.group(2)
            else:
                debug("Warning: Unknown thread! Will use 1")
                thread = "1"

            f = open(fname, 'r', encoding="latin-1")
            data = {}

            for l in f:
                if len(l) < 3:
                    continue
                m = alreadyRe.match(l)
                if m:
                  fil = m.group(1).strip()
                  conn.execute('UPDATE f SET chosen=(chosen + 1) where file="' + fil + '"')
                  continue

                m = projectRe.match(l)
                if m:
                  if bufferedLines != ""  and len(data) > 0:
                      insertFile(data, bufferedLines)
                  data = {"size" : m.group(1), "fid" : insertedFiles, "file" : m.group(2), "thread" : thread, "project" : m.group(3).strip("/"), "chosen" : 1}
                  bufferedLines = []
                  continue
                bufferedLines.append(l)
            f.close()
            num = num + 1
        except FileNotFoundError:
            print("Error while processing!")
            if debug:
                traceback.print_exc()
            conn.commit()
        print("Imported %d files, imported %d tuples" % (insertedFiles - lastFiles, insertedTuples - lastTuples))
    if bufferedLines != "" and len(data) > 0:
        insertFile(data, bufferedLines)
    print("Total in database %d files, %d tuples" % (insertedFiles, insertedTuples))
    conn.commit()

parse(files, parser, prefix)

conn.close()
