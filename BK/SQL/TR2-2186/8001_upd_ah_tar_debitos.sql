DECLARE
 v_can_procesar number:=5;
 v_can_reg_det  number:=0;
 v_nom_proceso  ge_log_errores.cod_programa%type:='UPDATE_TD_UUID_ID';
 v_cod_persona  ah_tar_debitos.cod_persona%type;
 v_nro_cuenta   ah_tar_debitos.nro_cuenta%type;
  -- Declaración del cursor
CURSOR DEBITO IS
    select s.cod_persona,
           s.nro_cuenta,
           it.fut_obt_cod_uuid(s.fec_insercion)UUIDv7,
           rowid id
    from ah_tar_debitos s 
    where s.cod_ent_procesadora='1175' 
      and s.id is null 
      and s.tar_activa='S'
      order by rowid;

BEGIN
  -- Inicialización de la aplicación
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;

  FOR a IN DEBITO LOOP
    v_can_reg_det:= v_can_reg_det+1;
    v_cod_persona:= a.cod_persona;
    v_nro_cuenta := a.nro_cuenta;
     
    UPDATE ah_tar_debitos s
       SET s.id = a.UUIDv7
     WHERE s.rowid = a.id;
       
    IF MOD(v_can_reg_det, v_can_procesar) = 0 THEN
         commit;
    END IF;
  END LOOP;
  -- Confirmar transacción
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    -- Manejo de errores
     PRG_INS_LOG_ERRORES(v_nom_proceso,
                         'Error: ' ||SQLERRM,
                         'COD_PERSONA',
                         v_cod_persona,
                         'NRO_CUENTA',
                         v_nro_cuenta);
    ROLLBACK;
END;
