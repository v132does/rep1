create or replace function it.fug_obt_cod_uuid return VARCHAR2 is
  v_uuid VARCHAR2(40);
begin
  select regexp_replace(rawtohex(sys_guid()), '([A-F0-9]{8})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{12})', '\1-\2-\3-\4-\5')
  into v_uuid from dual;
  --Lower para swift
  v_uuid:=lower(v_uuid);
  return v_uuid;
end fug_obt_cod_uuid;
/

