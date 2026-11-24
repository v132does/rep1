CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAI_CAN_LIN_SOB IS

  V_DIR_CORREO_DE   VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_SOBREGIRO');--'sobregiros@bbva.com.py';
  V_DIR_CORREO_PARA VARCHAR2(300);
  V_FEC_ACTUAL      DATE := TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1));
  V_COD_OFICINA      BA_USUARIOS.COD_OFICINA%TYPE;
  V_GESTOR           GE_CLIENTES.COD_USU_GESTION%TYPE;
  v_dir_cor_gte_suc  BA_USUARIOS.DIR_CORREO%TYPE;
  v_conn           utl_smtp.connection;
  v_det_error        ge_ra_log_mail.det_error%type;
  v_asunto           varchar2(1000);

  V_DETALLE  VARCHAR(1000);

  CURSOR C_PERSONAS IS
    -- RENOVADO
    SELECT s.nro_secuencia nro_lin_sobregiro,
           s.fec_vencimiento as vencimiento,
           s.cod_moneda as moneda,
           s.cod_persona as persona,
           fue_obt_nom_persona(s.cod_persona) as nombre,
           s.monto as monto,
           'NO RENOVADA' estado,
           m.val_parametro motivo
      FROM cc_lin_sobregiros s, ba_tab_dat_adicionales a, ba_tab_dat_adicionales m
     WHERE a.tab_relacion = 'CC_LIN_SOBREGIROS'
       AND a.referencia = s.nro_secuencia
       AND a.parametro = 'RENOVAR'
       AND a.val_parametro = 'N'
       and m.tab_relacion = 'CC_LIN_SOBREGIROS'
       AND m.referencia = s.nro_secuencia
       AND m.parametro = 'DES_MOT_NO_RENOVACION'
       AND v_fec_actual >= add_months(s.fec_vencimiento,-2)
       AND nvl(s.observacion_his, 'x') not like '%-NOTIFICADO POR MAIL-%'                  
    UNION ALL
    SELECT s.nro_secuencia nro_lin_sobregiro,
           s.fec_vencimiento as vencimiento,
           s.cod_moneda as moneda,
           s.cod_persona as persona,
           fue_obt_nom_persona(s.cod_persona) as nombre,
           s.monto as monto,
           'CANCELADA' estado,
           m.val_parametro
      FROM cc_lin_sobregiros s, ba_tab_dat_adicionales a, ba_tab_dat_adicionales m
     WHERE s.estado = 'C'
       and a.tab_relacion = 'CC_LIN_SOBREGIROS'
       AND a.referencia = s.nro_secuencia
       AND a.parametro = 'FEC_CANCELACION'
       AND to_date(a.val_parametro, 'DD/MM/YYYY') = v_fec_actual
       and m.tab_relacion = 'CC_LIN_SOBREGIROS'
       AND m.referencia = s.nro_secuencia
       AND m.parametro = 'DES_MOT_NO_RENOVACION'
       AND nvl(s.observacion_his, 'x') not like '%-NOTIFICADO POR MAIL-%'                  
     order by 4;

BEGIN
  FOR REC IN C_PERSONAS LOOP
    begin
       select a.cod_usu_oficial, a.cod_oficina
         into V_GESTOR, V_COD_OFICINA
         from ge_clientes a
        where a.cod_persona = REC.PERSONA;
    exception
       when others then
         V_GESTOR      := null;
         V_COD_OFICINA := null;
    end;

    V_DIR_CORREO_PARA := '';


    if v_gestor is not null then

       V_DIR_CORREO_PARA := fug_obt_dir_mail_usu(V_GESTOR);

       if v_dir_correo_para is not null and v_dir_cor_gte_suc is not null then
          v_dir_correo_para := v_dir_correo_para ||'; '||v_dir_cor_gte_suc;
       elsif v_dir_correo_para is null and v_dir_cor_gte_suc is not null then
          v_dir_correo_para := v_dir_cor_gte_suc;
       end if;

       if V_DIR_CORREO_PARA is null then

          V_DIR_CORREO_PARA := FUG_OBT_PARDINAMICO('EMAIL_LINEA_SOB');

       end if;

    else

       V_DIR_CORREO_PARA := FUG_OBT_PARDINAMICO('EMAIL_LINEA_SOB');

    end if;
    IF rec.estado = 'CANCELADA' then
      V_DETALLE := '<html>
                <head>
                  <title>Test HTML message</title>
                </head>
                <body>
                  <p>Se informa,
                  <br><br>
                   Que fué CANCELADA la linea de sobregiro Nro: '||rec.nro_lin_sobregiro|| ' en moneda <i>' ||
                   REC.MONEDA || '</i>
                  otorgada a la persona <i>' || REC.PERSONA ||
                   ' - ' || REC.NOMBRE || '</i> de monto <i>' || REC.Monto  ||'</i>'||
                   ' <br><i>'||rec.motivo||'</i>'||
                   '</i> <br><br> Atentamente,
                  </p>
                </body>
              </html>';
    ELSE
      V_DETALLE := '<html>
                <head>
                  <title>Test HTML message</title>
                </head>
                <body>
                  <p>Se informa,
                  <br><br>
                     Que NO será renovada la linea de sobregiro Nro: '||rec.nro_lin_sobregiro|| ' en moneda <i>' ||
                   REC.MONEDA || '</i>
                  otorgada a la persona <i>' || REC.PERSONA ||
                   ' - ' || REC.NOMBRE || '</i> de monto <i>' || REC.Monto ||'</i>'||
                   ' <br> Motivo: '|| '<i>'||rec.motivo||'</i>'||
                   ' <br><br> Atentamente,
                   </p>
                 </body>
              </html>';
    END IF;

    if rec.estado = 'CANCELADA' then
       v_asunto:= 'LINEA DE SOBREGIRO CANCELADA, CLIENTE: '||REC.PERSONA || ' - ' || REC.NOMBRE;
    else
       v_asunto:= 'LINEA DE SOBREGIRO NO SERÁ RENOVADA, CLIENTE: '||REC.PERSONA || ' - ' || REC.NOMBRE;
    end if;

    BEGIN
      v_conn     := it_mail.begin_mail(V_DIR_CORREO_DE,
                                       V_DIR_CORREO_PARA,
                                       v_asunto,
                                       IT_MAIL.MULTIPART_MIME_TYPE);



      it_mail.attach_text(v_conn, v_detalle, 'text/html');
      it_mail.end_mail(v_conn);
    EXCEPTION
      when others then
         v_det_error := sqlerrm;
         INSERT INTO ge_ra_log_mail
           (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_dir_correo_para, v_asunto,
            v_det_error, null, null);
          COMMIT;
    end;
    if v_det_error is null then
       begin
         update cc_lin_sobregiros
            set observacion_his = nvl(observacion_his, '-')||'-NOTIFICADO POR MAIL-'
          where nro_secuencia = rec.nro_lin_sobregiro;
       exception
         when others then
             RAISE_APPLICATION_ERROR(-20001, 'ERROR AL ENVIAR EL MAIL. ' || SQLERRM);
       end;
     end if;    
    EXIT WHEN C_PERSONAS%NOTFOUND;
  END LOOP;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR AL ENVIAR EL MAIL. ' || SQLERRM);
END;
/

