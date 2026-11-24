CREATE OR REPLACE PACKAGE IT.WEBUTIL_DB AUTHID CURRENT_USER AS



  FUNCTION  OpenBlob(blobTable  in VARCHAR2,
                     blobColumn in VARCHAR2,
                     blobWhere  in VARCHAR2,
                     openMode   in VARCHAR2,
                     chunkSize  in PLS_INTEGER default null) return BOOLEAN;

  FUNCTION  CloseBlob(checksum in PLS_INTEGER) return BOOLEAN;

  PROCEDURE WriteData(data in VARCHAR2);

  FUNCTION ReadData return VARCHAR;

  FUNCTION GetLastError return PLS_INTEGER;

  FUNCTION GetSourceLength  return PLS_INTEGER;

  FUNCTION GetSourceChunks  return PLS_INTEGER;

END WEBUTIL_DB;
/

