create or replace function it.fug_des_clave(p_valor in varchar2,
                                            p_llave in varchar2 default '12345678')
  RETURN varchar2 IS
  v_desencriptado varchar2(2048);
  v_valor         varchar2(1000);
BEGIN
  v_valor := utl_raw.cast_to_varchar2(hextoraw(p_valor));
  dbms_obfuscation_toolkit.DESDecrypt(input_string     => v_valor,
                                      key_string       => p_llave,
                                      decrypted_string => v_desencriptado);

  return trim(v_desencriptado);

end;
/

