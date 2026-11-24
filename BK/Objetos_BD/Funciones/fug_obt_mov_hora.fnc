CREATE OR REPLACE FUNCTION IT.fug_obt_mov_hora return varchar2 is
  v_hora    ge_movimientos.hora%type;
  v_nro_sec number;
  v_nro_hor number;
BEGIN
  
  v_nro_sec := fue_obt_sig_secuencia('s_nro_hora');

  if v_nro_sec <= 86400 then
    v_nro_hor := v_nro_sec;
  else
    v_nro_hor := mod(v_nro_sec, 86400);
  end if;

  v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
            TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
            TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

  return v_hora;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'No se puede obtener la hora del movimiento. ' ||
                            sqlerrm);
END;
/

