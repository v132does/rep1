CREATE OR REPLACE PROCEDURE IT.vale_load_file (
pdname VARCHAR2,
psname VARCHAR2,
pfname VARCHAR2) IS

src_file BFILE;
dst_file BLOB;
lgh_file BINARY_INTEGER;
BEGIN
src_file := bfilename('c:\', pfname);


INSERT INTO vale_pdm
(dname, sname, fname, iblob)
VALUES
(pdname, psname, pfname, EMPTY_BLOB())
RETURNING iblob INTO dst_file;


SELECT iblob
INTO dst_file
FROM vale_pdm
WHERE dname = pdname
AND sname = psname
AND fname = pfname
FOR UPDATE;


dbms_lob.fileopen(src_file, dbms_lob.file_readonly);


lgh_file := dbms_lob.getlength(src_file);


dbms_lob.loadfromfile(dst_file, src_file, lgh_file);


UPDATE vale_pdm
SET iblob = dst_file
WHERE dname = pdname
AND sname = psname
AND fname = pfname;


dbms_lob.fileclose(src_file);
END vale_load_file;
/

