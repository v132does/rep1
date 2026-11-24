create or replace function it.fug_enc_clave(p_valor in varchar2,
                                         p_llave in varchar2 default '12345678')
  RETURN varchar2 IS
  v_encriptado VARCHAR2(2048);
  v_valor       varchar2(100);
  v_longitud    number(8);
BEGIN
  v_longitud :=  (trunc(length(p_valor) / 8) + 1) * 8;
  v_valor    := rpad(p_valor, v_longitud, ' ');
  dbms_obfuscation_toolkit.DESEncrypt(input_string     => v_valor,
                                      key_string       => p_llave,
                                      encrypted_string => v_encriptado);
  return rawtohex(UTL_RAW.CAST_TO_RAW(v_encriptado));

end;
/

