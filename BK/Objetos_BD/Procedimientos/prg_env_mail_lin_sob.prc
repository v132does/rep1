CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_LIN_SOB IS

  V_DIR_CORREO_DE   VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_SOBREGIRO');--'sobregiros@bbva.com.py';
  V_DIR_CORREO_PARA VARCHAR2(300);
  V_FEC_ACTUAL      DATE := TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1));
  V_CAN_DIA_NOT_LIM_CRE NUMBER := fug_obt_pardinamico('CAN_DIA_NOT_LIM_CRE');
  V_FEC_VENCIMIENTO DATE := V_FEC_ACTUAL + nvl(V_CAN_DIA_NOT_LIM_CRE, 30);
  V_GRU_AGE_GTE_SUC  ba_usuarios.gru_agenda%type := fug_obt_pardinamico('GRU_AGE_GTE_SUC');
  V_COD_OFICINA      BA_USUARIOS.COD_OFICINA%TYPE;
  V_GESTOR           GE_CLIENTES.COD_USU_GESTION%TYPE;
  v_ger_sucursal     BA_USUARIOS.COD_USUARIO%TYPE;
  v_dir_cor_gte_suc  BA_USUARIOS.DIR_CORREO%TYPE;
  v_conn           utl_smtp.connection;
  v_det_error        ge_ra_log_mail.det_error%type;

  V_DETALLE  VARCHAR(1000);

  CURSOR C_PERSONAS IS

    SELECT a.fec_vencimiento as vencimiento,
           a.cod_moneda as moneda,
           a.cod_persona as persona,
           fue_obt_nom_persona(a.cod_persona) as nombre,
           trim(a.descripcion) as descripcion,
           a.monto as monto,
           a.mto_aplicado as aplicado,
           CASE a.estado
             WHEN 'P' THEN
              'PENDIENTE'
             WHEN 'A' THEN
              'APROBADO'
             WHEN 'V' THEN
              'VENCIDO'
             WHEN 'B' THEN
              'BLOQUEADO'
             WHEN 'C' THEN
              'CANCELADO'
             WHEN 'R' THEN
              'RECHAZADO'
           END as estado,
           a.observacion as obs
      FROM PR_LINEAS A
     WHERE TRUNC(A.FEC_VENCIMIENTO) = V_FEC_VENCIMIENTO
       AND A.ESTADO IN ('A','B'); ---DYDMR-7074 - Incidencia SAU - ITGF - Linea de Credito a Vencer, Cliente: 639187

BEGIN



  FOR REC IN C_PERSONAS LOOP
     ---DYDMR-6820 - Incidencia SAU - ITGF - Envia Mail Lineas de Cred. Vencidas
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
    begin
      select u.cod_usuario
        into v_ger_sucursal
        from ba_usuarios u
       where u.cod_oficina = v_cod_oficina
         and u.estado = 'A'
         and u.gru_agenda = V_GRU_AGE_GTE_SUC
         and rownum = 1;
    exception
      when others then
        v_ger_sucursal := null;
    end;

    if v_ger_sucursal is not null then
       v_dir_cor_gte_suc := fug_obt_dir_mail_usu(v_ger_sucursal);
    end if;

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


    V_DETALLE := '<html>
              <head>
                <title>Test HTML message</title>
              </head>
              <body>
                <p>En fecha <i>' || REC.VENCIMIENTO ||
                 '</i> pasara a estado <b>VENCIDO</b> la linea de credito en moneda <i>' ||
                 REC.MONEDA || '</i>
                otorgada a la persona <i>' || REC.PERSONA ||
                 ' - ' || REC.NOMBRE || '</i> de monto <i>' || REC.Monto ||
                 '</i> para uso dentro en la funcionalidad de <i>' ||
                 REC.Descripcion || '</i> <br><br> Atentamente,
                </p>
                <p><img src="'|| fug_obt_pardinamico('URL_BCO_LOGO')||'" alt="Site Logo" />
              </body>
            </html>';

    BEGIN                 
      v_conn     := it_mail.begin_mail(V_DIR_CORREO_DE,
                                       V_DIR_CORREO_PARA,
                                       'LINEA DE CREDITO A VENCER, CLIENTE: ' ||REC.PERSONA || ' - ' || REC.NOMBRE,
                                       IT_MAIL.MULTIPART_MIME_TYPE);
                                       
                                       
                          
      it_mail.attach_text(v_conn, v_detalle, 'text/html');
      it_mail.end_mail(v_conn);
    EXCEPTION
      when others then
         v_det_error := sqlerrm;
         INSERT INTO ge_ra_log_mail
           (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_dir_correo_para, 'LINEA DE CREDITO A VENCER, CLIENTE: ' ||REC.PERSONA || ' - ' || REC.NOMBRE, 
            v_det_error, null, null);
          COMMIT;
    end;
    
    EXIT WHEN C_PERSONAS%NOTFOUND;
  END LOOP;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR AL GENERAR LISTADO2. ' || SQLERRM);
END;
/

