CREATE OR REPLACE FUNCTION IT.fug_con_lob(c IN CLOB) RETURN BLOB
-- typecasts CLOB to BLOB (binary conversion)
 IS
   pos     PLS_INTEGER := 1;
   buffer  RAW(32767);
   res     BLOB;
   lob_len PLS_INTEGER := dbms_lob.getlength(c);
BEGIN
   dbms_lob.createtemporary(res, TRUE);
   dbms_lob.open(res, dbms_lob.lob_readwrite);

   LOOP
      buffer := utl_raw.cast_to_raw(dbms_lob.substr(c, 16000, pos));
   
      IF utl_raw.length(buffer) > 0 THEN
         dbms_lob.writeappend(res, utl_raw.length(buffer), buffer);
      END IF;
   
      pos := pos + 16000;
      EXIT WHEN pos > lob_len;
   END LOOP;

   RETURN res; -- res is OPEN here
END fug_con_lob;
/

