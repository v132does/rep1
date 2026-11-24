CREATE OR REPLACE PROCEDURE IT.prg_gen_ofe_pre_aprobado(p_cod_persona ba_personas.cod_persona%TYPE,
                                                        p_rta_rrnn    VARCHAR2,
                                                        p_can_cuota   NUMBER,
                                                        p_mto_oferta  NUMBER,
                                                        p_cod_error   OUT NUMBER,
                                                        p_msj_error   OUT VARCHAR2) IS
  --
  v_cod_error NUMBER;
  v_msj_error VARCHAR2(2000);
  --
  v_cod_pre_aprobado     NUMBER;
  v_cod_pla_pre_aprobado pr_pre_aprobados.cod_pla_pre_aprobado%TYPE;
  v_cod_registro         NUMBER;
  v_can_mes_vig_ofe      NUMBER := fug_obt_pardinamico('GEN_CAN_DIA_VIG_OFE_ONB');
  ---
  v_dir_mail           ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('GEN_PRE_OFE_ONB_CORREOS');
  v_asunto             varchar2(2000) := 'Oferta Rechaza en analisis en Onboarding.';
  v_txt_mail           varchar2(2000);
  v_remitente          ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  v_mto_lim_pre        NUMBER;
  v_mto_cuo_aproximado it.ba_per_gen_ofertas.mto_cuo_aproximado%type;
  v_con_ingreso        varchar2(1);
  v_cod_err_tar        number;
  v_msj_err_tar        VARCHAR2(4000);
  v_tip_ingreso        it.ge_ing_clientes.tip_ingreso%type;
  v_monto_ingreso      it.ge_ing_clientes.mon_ingreso%type;
BEGIN
  v_cod_error := null;
  v_msj_error := null;
  --
  --Recuperamos el tipo de ingreso: Si tip_ingreso = 4 no generar crédito si TC.
  BEGIN
    SELECT o.tip_ingreso
      INTO v_tip_ingreso
      FROM ge_ing_clientes o
     WHERE o.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN others THEN
      null;
  END;
  BEGIN
    SELECT o.cod_registro, o.mto_lim_prestable, o.mto_cuo_aproximado, o.mto_ingreso
      INTO v_cod_registro, v_mto_lim_pre, v_mto_cuo_aproximado, v_monto_ingreso 
      FROM ba_per_gen_ofertas o
     WHERE o.cod_persona = p_cod_persona
       AND o.est_servicios = 'V'
       AND o.est_rrnn = 'P';
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_error := 5;
      v_msj_error := 'ERROR. Oferta no encontrada para el cliente ' ||
                     p_cod_persona;
    WHEN too_many_rows THEN
      SELECT o.cod_registro, o.mto_lim_prestable
        INTO v_cod_registro, v_mto_lim_pre
        FROM ba_per_gen_ofertas o
       WHERE o.cod_persona = p_cod_persona
         AND o.est_servicios = 'V'
         AND o.est_rrnn = 'P'
         AND o.fec_consulta = (SELECT min(oo.fec_consulta)
                                 FROM ba_per_gen_ofertas oo
                                WHERE oo.cod_persona = p_cod_persona
                                  AND oo.est_servicios = 'V'
                                  AND oo.est_rrnn = 'P');
    WHEN OTHERS THEN
      v_cod_error := 6;
      v_msj_error := 'ERROR. Al buscar la oferta ' || SQLERRM;
  END;
  IF nvl(v_cod_error, '000') = '000' THEN
    IF upper(p_rta_rrnn) <> 'ACEPTAR' THEN
      IF upper(p_rta_rrnn) = 'RECHAZAR' THEN
        UPDATE ba_per_gen_ofertas o
           SET o.est_rrnn     = 'R',
               o.fec_consulta = pag_cal.FU_OBT_FEC_ACTUAL(1),
               o.rta_rrnn     = p_rta_rrnn
         WHERE o.cod_persona = p_cod_persona
           AND o.cod_registro = v_cod_registro
           AND o.est_servicios = 'V'
           AND o.est_rrnn = 'P';
      ELSE
        UPDATE ba_per_gen_ofertas o
           SET o.est_rrnn     = 'E',
               o.fec_consulta = pag_cal.FU_OBT_FEC_ACTUAL(1),
               o.rta_rrnn     = p_rta_rrnn
         WHERE o.cod_persona = p_cod_persona
           AND o.cod_registro = v_cod_registro
           AND o.est_servicios = 'V'
           AND o.est_rrnn = 'P';
      END IF;
      --enviar correo
      v_txt_mail := 'Cliente: ' || p_cod_persona || ' - ' ||
                    fue_obt_nom_persona(p_cod_persona) || chr(10) ||
                    'Mto. Oferta: ' || p_mto_oferta || chr(10) ||
                    'Cuotas: ' || p_can_cuota || chr(10);
    
      it_mail.mail(v_remitente, -- quien envia
                   v_dir_mail, -- a quien
                   v_asunto, -- asunto
                   v_txt_mail);
    ELSIF upper(p_rta_rrnn) = 'ACEPTAR' THEN
      IF nvl(fug_obt_pardinamico('GEN_OFE_PRE_APROBADOS'), 'N') = 'N' THEN
        --
        BEGIN
          SELECT max(cod_pre_aprobado)
            INTO v_cod_pre_aprobado
            FROM pr_pre_aprobados_tmp_mom;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_pre_aprobado := 0;
          WHEN OTHERS THEN
            v_cod_pre_aprobado := 0;
        END;
        --
        BEGIN
          SELECT s_cod_pla_pre_ofe.nextval
            INTO v_cod_pla_pre_aprobado
            FROM dual;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 10;
            v_msj_error := 'No se encuentra la secuencia del registro.';
          WHEN OTHERS THEN
            v_cod_error := 11;
            v_msj_error := 'No se encuentra la secuencia del registro.';
        END;
        --  
        IF v_mto_lim_pre > 0 THEN
          v_cod_pla_pre_aprobado := 'ONB. C/ ING ' ||
                                    v_cod_pla_pre_aprobado;
          v_con_ingreso          := 'S';
        ELSE
          v_cod_pla_pre_aprobado := 'ONB. S/ ING ' ||
                                    v_cod_pla_pre_aprobado;
          v_con_ingreso          := 'N';
        END IF;
        insert into pr_pre_aprobados_tmp_mom
          (COD_PRE_APROBADO,
           COD_PLA_PRE_APROBADO,
           FEC_INI_OFERTA,
           FEC_FIN_OFERTA,
           COD_PERSONA,
           MON_PRE_APROBADO,
           CAN_CUOTA,
           COD_MONEDA,
           COD_OFICINA,
           COD_USU_OFICIAL,
           TIP_AMORTIZACION,
           COD_MODALIDAD,
           COD_RUB_ECONOMICO)
        values
          (nvl(v_cod_pre_aprobado, 1),
           v_cod_pla_pre_aprobado,
           pag_cal.FU_OBT_FEC_ACTUAL(6),
           add_months(pag_cal.fu_obt_fec_actual(6), v_can_mes_vig_ofe),
           p_cod_persona,
           p_mto_oferta,
           p_can_cuota,
           pag_gen.FU_OBT_MON_LOCAL,
           96,
           'OVIRTUAL',
           'P',
           602,
           '970108');
      ELSE
        --
        BEGIN
          SELECT max(cod_pre_aprobado)
            INTO v_cod_pre_aprobado
            FROM pr_pre_aprobados;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_pre_aprobado := 0;
          WHEN OTHERS THEN
            v_cod_pre_aprobado := 0;
        END;
        --
        BEGIN
          SELECT s_cod_pla_pre_ofe.nextval
            INTO v_cod_pla_pre_aprobado
            FROM dual;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 10;
            v_msj_error := 'No se encuentra la secuencia del registro.';
          WHEN OTHERS THEN
            v_cod_error := 11;
            v_msj_error := 'No se encuentra la secuencia del registro.';
        END;
        --  
        IF v_mto_lim_pre > 0 THEN
          v_cod_pla_pre_aprobado := 'ONB. C/ ING ' ||
                                    v_cod_pla_pre_aprobado;
          v_con_ingreso          := 'S';
        ELSE
          v_cod_pla_pre_aprobado := 'ONB. S/ ING ' ||
                                    v_cod_pla_pre_aprobado;
          v_con_ingreso          := 'N';
        END IF;
        IF v_tip_ingreso <> 4 then
        insert into pr_pre_aprobados
          (COD_PRE_APROBADO,
           COD_PLA_PRE_APROBADO,
           FEC_INI_OFERTA,
           FEC_FIN_OFERTA,
           COD_PERSONA,
           MON_PRE_APROBADO,
           CAN_CUOTA,
           COD_MONEDA,
           COD_OFICINA,
           COD_USU_OFICIAL,
           TIP_AMORTIZACION,
           COD_MODALIDAD,
           COD_RUB_ECONOMICO)
        values
          (v_cod_pre_aprobado,
           v_cod_pla_pre_aprobado,
           pag_cal.FU_OBT_FEC_ACTUAL(6),
           add_months(pag_cal.fu_obt_fec_actual(6), v_can_mes_vig_ofe),
           p_cod_persona,
           p_mto_oferta,
           p_can_cuota,
           pag_gen.FU_OBT_MON_LOCAL,
           96,
           'OVIRTUAL',
           'P',
           602,
           '970108');
           END IF;
          IF nvl(fug_obt_pardinamico('GEN_OFE_TAR_ONBOARDING'), 'N') = 'S' THEN 
              begin
                IF v_tip_ingreso in (1,2) and v_monto_ingreso > 0 and v_monto_ingreso < p_mto_oferta THEN
                /*Inserta linea pre aprobada para tarjeta de credito, Topea un salario*/
                   PRT_INS_LIN_PRE_APROBADO(p_cod_persona,
                                            v_monto_ingreso,
                                            (v_monto_ingreso/10),
                                            v_cod_pla_pre_aprobado,
                                            v_con_ingreso,
                                            v_cod_err_tar,
                                            v_msj_err_tar);
                 ELSE
                   /*Inserta linea pre aprobada para tarjeta de credito, segun su capacidad de ingreso*/
                   PRT_INS_LIN_PRE_APROBADO(p_cod_persona,
                                            p_mto_oferta,
                                            v_mto_cuo_aproximado,
                                            v_cod_pla_pre_aprobado,
                                            v_con_ingreso,
                                            v_cod_err_tar,
                                            v_msj_err_tar);
                   END IF;
              exception
                when others then 
                  /*si ocurre un error se guarda en el log y deja concluir el proceso de pre aprobados principal*/
                  null;
              end;
          END IF;    
      END IF;
    
      UPDATE ba_per_gen_ofertas o
         SET o.est_rrnn     = 'V',
             o.fec_consulta = pag_cal.FU_OBT_FEC_ACTUAL(1),
             o.rta_rrnn     = p_rta_rrnn
       WHERE o.cod_persona = p_cod_persona
         AND o.cod_registro = v_cod_registro
         AND o.est_servicios = 'V'
         AND o.est_rrnn = 'P';
    END IF;
  END IF;
  --
  IF nvl(v_cod_error, '000') = '000' THEN
    v_cod_error := 0;
    v_msj_error := 'Proceso concluido con exito.';
  END IF;
  p_cod_error := v_cod_error;
  p_msj_error := v_msj_error;
END;
/
