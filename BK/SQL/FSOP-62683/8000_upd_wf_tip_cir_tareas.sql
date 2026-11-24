Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE wf_tip_cir_tareas
   SET det_sql = 'DECLARE
   v_cod_persona varchar2(15);
   v_cod_causal ge_per_inhibidas.cod_causa%TYPE ;
   v_wf_error   varchar2(2000);
BEGIN
     SELECT cod_persona
        INTO v_cod_persona
       FROM wf_circuitos
     WHERE cod_circuito = ''&'||'COD_CIRCUITO'';

   v_cod_causal := fug_obt_pardinamico(''PER_COINCIDENCIA'');

     IF ''&'||'TIP_ACCION'' = ''A'' THEN

          UPDATE ba_personas
                 SET est_verificacion = ''V'',
                         cod_usu_verificador = user,
                         fec_verificacion = pag_cal.fu_obt_fec_actual(1)
             WHERE cod_persona = v_cod_persona;

      PRG_GEN_INH_PER(v_cod_persona,
                         v_cod_causal,
                         ''PERSONA CON COINCIDENCIA VIGIA'',
                         ''D'');


      ELSIF ''&'||'TIP_ACCION'' = ''R'' THEN
         PRG_GEN_INH_PER(v_cod_persona,
                         v_cod_causal,
                         ''PERSONA CON COINCIDENCIA VIGIA'',
                         ''I'');

          v_wf_error := paw_cir.fu_fin_cir_pendientes(7, v_cod_persona);

          IF v_wf_error <> 0 THEN
              raise_application_error(-20000, ''Error al finalizar la Tarea de Workflow'');
          END IF;

      END IF;
END;'
 WHERE cod_tip_circuito = 7
   AND cod_tip_tarea = 1;

--Activar Tareas   
update wf_tip_cir_tareas
set    estado = 'A'
where cod_tip_circuito = 7;

--Grupo responsable  
update wf_tip_cir_tareas
set    cod_gru_responsable = 11
where cod_tip_circuito = 7
and   cod_tip_tarea    = 0;

update wf_tip_cir_tareas
set    cod_gru_responsable = 13
where cod_tip_circuito = 7
and   cod_tip_tarea    = 1;

commit;
