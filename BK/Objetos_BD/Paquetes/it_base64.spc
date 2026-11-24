CREATE OR REPLACE PACKAGE IT.it_base64 IS

   -- Base64-encode a piece of binary data.
   --
   -- Note that this encode function does not split the encoded text into
   -- multiple lines with no more than 76 bytes each as required by
   -- the MIME standard.
   --
   FUNCTION encode(r IN RAW) RETURN VARCHAR2;

END;
/

