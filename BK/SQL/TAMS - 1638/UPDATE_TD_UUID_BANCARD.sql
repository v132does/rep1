DECLARE
 v_can_actualizar   NUMBER;
 v_can_procesar     CONSTANT PLS_INTEGER := 5;
 v_contador         PLS_INTEGER :=0 ;
 v_can_actualizados NUMBER ;
 v_nom_proceso      ge_log_errores.cod_programa%type:='UPDATE_TD_UUID_BANCARD';
 v_cod_persona      ta_tarjetas.cod_persona%type;
 v_nro_cuenta       ta_tarjetas.nro_cuenta%type;
 v_last_four        NUMBER;


CURSOR DEBITO IS


        SELECT s.cod_persona,
               s.nro_cuenta,
               it.fut_obt_cod_uuid(FROM_TZ(CAST(s.fec_insercion AS TIMESTAMP), SESSIONTIMEZONE)) UUIDv7,
               SUBSTR(s.nro_tarjeta,-4) last_four,
               rowid id
        FROM ah_tar_debitos s 
        WHERE s.id is null;

BEGIN

   SELECT count(*)
   INTO v_can_actualizar
    FROM  ah_tar_debitos s 
    WHERE s.id is null;

DBMS_OUTPUT.PUT_LINE ('Cantidad de registros actualizar: '|| v_can_actualizar );

  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;

  FOR d IN DEBITO LOOP
    v_contador   := v_contador + 1;
    v_cod_persona:= d.cod_persona;
    v_nro_cuenta := d.nro_cuenta;
    v_last_four  := d.last_four;

    UPDATE ah_tar_debitos
       SET id = d.UUIDv7
    WHERE rowid = d.id 
    AND id IS NULL;

    IF MOD(v_contador, v_can_procesar) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;

  COMMIT;

  select count(*) 
  into v_can_actualizados
  FROM  ah_tar_debitos s 
  WHERE s.fec_modificacion>=trunc(sysdate)
  AND s.usu_modificacion=user;

    DBMS_OUTPUT.PUT_LINE ('Regitros actualizados: '|| v_can_actualizados );


EXCEPTION
  WHEN OTHERS THEN

   PRG_INS_LOG_ERRORES(v_nom_proceso,
                         'Error: ' ||SQLERRM,
                         'COD_PERSONA',
                         v_cod_persona,
                         'NRO_CUENTA',
                         v_nro_cuenta,
                         'LAST_FOUR',
                         v_last_four);

    ROLLBACK;

END;