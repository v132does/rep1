CREATE OR REPLACE PROCEDURE IT.prg_act_cumplimiento IS

  --Cursor del archivo tmp importado.
  CURSOR emp_cursor_per IS
    SELECT cod_persona
    FROM ge_per_cumplimiento_tmp;

     -- Variables para almacenar los datos del primer cursor
  v_cod_persona ba_personas.cod_persona%TYPE;
  v_cod_error    VARCHAR2(5) := 'OK';
  v_msj_error    VARCHAR2(1000) := 'Procesado con exito.';
  v_cod_causal ge_per_inhibidas.cod_causa%TYPE;

  -- Declaración del segundo cursor para tipos de circuitos
  CURSOR emp_cursor_cir IS
    SELECT cod_circuito,cod_tip_circuito
    FROM wf_circuitos
    WHERE cod_persona = v_cod_persona
    AND estado not in ('C', 'F')
    AND cod_tip_circuito in ('5','38','44');

    -- Variables para almacenar los datos del primer cursor
    v_cod_circuito wf_circuitos.cod_circuito%TYPE;
    v_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 1;
  end;
  -- Abrir y recorrer el primer cursor
  OPEN emp_cursor_per;
  LOOP
    FETCH emp_cursor_per INTO v_cod_persona;
    EXIT WHEN emp_cursor_per%NOTFOUND;

    -- Abrir y recorrer el segundo cursor
    OPEN emp_cursor_cir;
    LOOP
      FETCH emp_cursor_cir INTO v_cod_circuito, v_cod_tip_circuito;
      EXIT WHEN emp_cursor_cir%NOTFOUND;

          IF v_cod_error='OK' THEN

              --VERIFICACION PERSONAS PARECIDAS EN LISTAS
             IF v_cod_tip_circuito = 5 THEN
                begin
                  UPDATE ba_personas
                     SET est_verificacion    = 'V',
                         cod_usu_verificador = user,
                         fec_verificacion    = pag_cal.fu_obt_fec_actual(1)
                   WHERE cod_persona = v_cod_persona;
                exception
                  when others then
                    v_cod_error := 'ERROR';
                    prg_ins_log_programas('PRG_ACT_CUMPLIMIENTO',substr('1-ERROR: ' || sqlerrm,1,4000),null,v_cod_persona);
                end;
             END IF;


              --VERIFICACION DE CLIENTE CON COINCIDENCIAS
              IF v_cod_error='OK' THEN
                 IF v_cod_tip_circuito = 38 THEN
                    it.prw_per_dat_doc(v_cod_circuito,'A','','finalizacion masiva');
                 END IF;
              END IF;
              --VERIFICACION CLIENTE PEP
             IF v_cod_error='OK' THEN
              IF v_cod_tip_circuito = 44 THEN
                  begin
                    update ba_personas
                       set est_verificacion    = 'V',
                           cod_usu_verificador = user,
                           fec_verificacion    = pag_cal.fu_obt_fec_actual(1),
                           obs_verificacion    = 'finaliza masivo cumplimiento'
                     where cod_persona = v_cod_persona;
                  exception
                    when others then
                      v_cod_error := 'ERROR';
                      prg_ins_log_programas('PRG_ACT_CUMPLIMIENTO',substr('1-ERROR: ' || sqlerrm,1,4000),null,v_cod_persona);
                  end;
                  IF v_cod_error='OK' THEN
                    begin
                      update ge_per_inhibidas i
                           set i.estado = 'D'
                         where i.estado = 'I'
                           and i.cod_causa = fug_obt_pardinamico('PEP_ONBOARDING')
                           and i.cod_persona = v_cod_persona;
                     exception
                       when others then
                         prg_ins_log_programas('PRG_ACT_CUMPLIMIENTO',substr('1-ERROR: ' || sqlerrm, 1, 4000),null,v_cod_persona);
                     end;
                  END IF;
              END IF;
             END IF;

             IF v_cod_error='OK' THEN
                --Actualiza la tarea A Aprobado
                 BEGIN
                   UPDATE wf_cir_tareas ct
                      SET ct.estado = 'A'
                    WHERE ct.cod_circuito in(SELECT t.cod_circuito
                                               FROM wf_circuitos t
                                              WHERE t.cod_persona = v_cod_persona
                                                and t.cod_circuito= v_cod_circuito
                                                and t.cod_tip_circuito = v_cod_tip_circuito
                                                and t.estado not in ('C', 'F'))
                      AND ct.estado = 'P';
                      commit;
                 EXCEPTION
                   WHEN OTHERS THEN
                     v_cod_error := 'ERROR';
                      prg_ins_log_programas('PRG_ACT_WORKFLOW',substr('1-ERROR: ' || sqlerrm, 1, 4000),null,v_cod_persona);
                 END;

                  -- FINALIZA EL CIRCUITO
                  BEGIN
                    UPDATE wf_circuitos
                       SET estado = 'F'
                     WHERE cod_persona = v_cod_persona
                       AND estado not in ('C', 'F')
                       AND cod_circuito= v_cod_circuito
                       AND cod_tip_circuito=v_cod_tip_circuito;
                       commit;
                  EXCEPTION
                    WHEN OTHERS THEN
                      v_cod_error := 'ERROR';
                      prg_ins_log_programas('PRG_ACT_CUMPLIMIENTO',substr('1-ERROR: ' || sqlerrm, 1, 4000),null,v_cod_persona);
                  END;
             END IF;
        END IF;

    END LOOP;

    -- Cerrar el segundo cursor
    CLOSE emp_cursor_cir;
  END LOOP;

  -- Cerrar el primer cursor
  CLOSE emp_cursor_per;
END;
/
