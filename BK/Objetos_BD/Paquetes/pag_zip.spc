CREATE OR REPLACE PACKAGE IT.PAG_ZIP
is
  type file_list is table of clob;
--
  function get_file_list(
    p_dir in varchar2
  , p_zip_file in varchar2
  , p_encoding in varchar2 := null
  )
    return file_list;
--
  function get_file_list(
    p_zipped_blob in blob
  , p_encoding in varchar2 := null /* Use CP850 for zip files created with a German Winzip to see umlauts, etc */
  )
    return file_list;
--
  function get_file(
    p_dir in varchar2
  , p_zip_file in varchar2
  , p_file_name in varchar2
  , p_encoding in varchar2 := null
  )
    return blob;
--
  function get_file(
    p_zipped_blob in blob
  , p_file_name in varchar2
  , p_encoding in varchar2 := null
  )
    return blob;
--
  procedure add1file(
    p_zipped_blob in out blob
  , p_name in varchar2
  , p_content in blob
  );
--
  procedure finish_zip(
    p_zipped_blob in out blob
  );
--
  procedure save_zip(
    P_ZIPPED_BLOB IN BLOB
  , P_DIR IN VARCHAR2 := 'ORA_DIR'
  , p_filename in varchar2 := 'TEST.zip'
  );
--
/*
declare
  g_zipped_blob blob;
begin
  as_zip.add1file( g_zipped_blob, 'test1.txt', utl_raw.cast_to_raw( 'Dit is de laatste test! Waarom wordt dit dan niet gecomprimeerd?' ) );
  as_zip.add1file( g_zipped_blob, 'test1234.txt', utl_raw.cast_to_raw( 'En hier staat wat anders' ) );
  as_zip.finish_zip( g_zipped_blob );
  as_zip.save_zip( g_zipped_blob, 'MY_DIR', 'my.zip' );
end;
--
declare
  t_dir varchar2(100) := 'MY_DIR';
  t_zip varchar2(100) := 'my.zip';
  zip_files as_zip.file_list;
begin
  zip_files  := as_zip.get_file_list( t_dir, t_zip );
  for i in zip_files.first() .. zip_files.last
  loop
    dbms_output.put_line( zip_files( i ) );
    dbms_output.put_line( utl_raw.cast_to_varchar2( as_zip.get_file( t_dir, t_zip, zip_files( i ) ) ) );
  end loop;
end;
*/
end;
/

