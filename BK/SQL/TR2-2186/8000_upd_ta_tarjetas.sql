DECLARE
 v_can_procesar CONSTANT PLS_INTEGER := 5;
 v_can_reg_det  PLS_INTEGER :=0 ;
 v_nom_proceso  ge_log_errores.cod_programa%type:='UPDATE_TC_UUID_ID';
 v_cod_persona  ta_tarjetas.cod_persona%type;
 v_nro_cuenta   ta_tarjetas.nro_cuenta%type;
  -- Declaración del cursor
CURSOR CREDITO IS
    select s.cod_persona,
           s.nro_cuenta,
           it.fut_obt_cod_uuid(s.fec_insercion)UUIDv7,
           rowid id
    from ta_tarjetas s 
    where s.id is null 
      and s.vigente='S'
      and exists (SELECT 1
                    FROM ta_cta_tarjetas a, (select distinct b.afinidad,
                                             b.cod_modalidad,
                                             b.cod_ent_procesadora
                                             from ta_tipos b
                                             where b.cod_ent_procesadora='1175')b
                   WHERE a.cod_modalidad = b.cod_modalidad
                     AND a.afinidad = b.afinidad
                     AND a.nro_cuenta=s.nro_cuenta)
      order by rowid;

BEGIN
  -- Inicialización de la aplicación
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;

  FOR a IN CREDITO LOOP
    v_can_reg_det:= v_can_reg_det+1;
    v_cod_persona:= a.cod_persona;
    v_nro_cuenta := a.nro_cuenta;
    
    UPDATE ta_tarjetas s
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
