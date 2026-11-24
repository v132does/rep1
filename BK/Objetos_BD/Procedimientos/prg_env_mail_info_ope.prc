CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_INFO_OPE IS

  V_DIR_CORREO_DE   VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  V_DIR_CORREO_PARA VARCHAR2(300);
  V_DIR_CORREO_CC   VARCHAR2(300) := fug_obt_pardinamico('DIR_MAI_COMEX');
  V_FEC_NO_ENVIO    VARCHAR2(60) :=  trim(to_char(TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1)),'DAY'));
  V_FEC_ACTUAL      DATE := TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1));
  V_DIAS            NUMBER := fug_obt_pardinamico('NOT_DIA_VEN_COMEX');
  V_FEC_VENCIMIENTO DATE := V_FEC_ACTUAL + NVL(V_DIAS,1);
  V_FEC_FIN         DATE := V_FEC_VENCIMIENTO;
  V_GESTOR          GE_CLIENTES.COD_USU_GESTION%TYPE;
  V_DETALLE  VARCHAR2(3000);
  V_CABECERA VARCHAR2(3000);
  v_hab_env_precalculo  varchar2(1);
  v_dat_pro_grupal      varchar2(8000);
  v_fec_proxima         date;
  v_ult_dia_mes_habil   date;

  CURSOR C_PERSONAS(P_FECHA_FIN DATE) IS

     select sa.nro_cuenta as CUENTA,
            fug_obt_des_modal(b.cod_modulo, b.cod_modalidad) as TIPO,
            sa.nro_cuota as CUOTA,
            sa.fec_vencimiento as VENCIMIENTO,
            CASE sa.estado
             WHEN 'P' THEN
              'PAGADO'
             WHEN 'N' THEN
              'PENDIENTE'
            END as ESTADO,
            b.cod_moneda as MONEDA,
            to_char(sa.monto,'999G999G999D99') as MONTO,
            to_char(sa.saldo,'999G999G999D99') as SALDO,
            fug_obt_cli_principal(sa.nro_cuenta) as PERSONA,
            fue_obt_nom_persona(fug_obt_cli_principal(sa.nro_cuenta)) as NOMBRE
     from cx_cuotas sa,
          ge_cuentas b
     where sa.nro_cuenta = b.nro_cuenta
       and trunc(sa.fec_vencimiento) between  V_FEC_ACTUAL and P_FECHA_FIN
       and sa.estado = 'N'
       order by 4,1,2;



BEGIN
  pag_cal.pr_obt_dat_calendar(3);
  v_fec_proxima := pag_cal.G_FEC_PROXIMA;
  v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
  
  if V_FEC_NO_ENVIO = 'VIERNES' then

   V_FEC_FIN := V_FEC_FIN + 2;

  end if;


  FOR REC IN C_PERSONAS(V_FEC_FIN) LOOP

    select a.cod_usu_oficial
    into   V_GESTOR
    from ge_clientes a
    where a.cod_persona = REC.PERSONA;

    V_DIR_CORREO_PARA := '';

    if v_gestor is not null then

       V_DIR_CORREO_PARA := fug_obt_dir_mail_usu(V_GESTOR);

       if V_DIR_CORREO_PARA is null then

          V_DIR_CORREO_PARA := FUG_OBT_PARDINAMICO('EMAIL_OPE_VENC');

       end if;

    else

       V_DIR_CORREO_PARA := FUG_OBT_PARDINAMICO('EMAIL_OPE_VENC');

    end if;

    V_CABECERA := '<html>
                  <body>
                         Buenos dias, remitimos el listado con los datos del cliente: <b>' || REC.PERSONA ||' - ' || REC.NOMBRE||'</b>, dicho cliente tiene operaciones con vencimientos futuros.
                  <br><br>
                  </p>
                  <table cellspacing="0"
                          cellpadding="5"
                          border="4">
                  <tr>
                    <td width="80%" bgcolor="4682B4"> <b>CUENTA</b>      </td>
                    <td width="80%" bgcolor="4682B4"> <b>TIPO</b>        </td>
                    <td width="80%" bgcolor="4682B4"> <b>CUOTA</b>       </td>
                    <td width="80%" bgcolor="4682B4"> <b>VENCIMIENTO</b> </td>
                    <td width="80%" bgcolor="4682B4"> <b>ESTADO</b>      </td>
                    <td width="80%" bgcolor="4682B4"> <b>MONEDA</b>      </td>
                    <td width="80%" bgcolor="4682B4"> <b>MONTO</b>       </td>
                    <td width="80%" bgcolor="4682B4"> <b>SALDO</b>       </td>
                    <td width="80%" bgcolor="4682B4"> <b>PERSONA</b>     </td>
                  </tr>';

    V_DETALLE := '<tr>
                    <td width="180%" bgcolor="B0C4DE">'||REC.CUENTA      ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.TIPO        ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.CUOTA       ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.VENCIMIENTO ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.ESTADO      ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.MONEDA      ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.MONTO       ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.SALDO       ||'</td>
                    <td width="180%" bgcolor="B0C4DE">'||REC.PERSONA     ||'</td>
                  </tr>
                </table>
                </i> <br><br> Atentamente,
                </p>
                <p><img src='|| fug_obt_pardinamico('URL_BCO_LOGO')||'" alt="Site Logo" />
              </body>
            </html>';

    PRG_SEND_MAIL(p_to    => V_DIR_CORREO_PARA,
              p_from      => V_DIR_CORREO_DE,
              p_subject   => 'OPERACIONES CON VENCIMIENTOS FUTUROS, CLIENTE: ' ||
                             REC.PERSONA,
              p_text_msg  => '',
              p_html_msg  => V_CABECERA||V_DETALLE,
              p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
              p_smtp_port => 25,
              pcc => V_DIR_CORREO_CC);

    EXIT WHEN C_PERSONAS%NOTFOUND;
  END LOOP;
  
  --Agregado para envio de emails de Pre-Calculo por Cuentas Transaccionales--
  v_hab_env_precalculo := nvl(fug_obt_pardinamico('DEV_GRU_HAB_ENV_PRECAL'),'N');
  if ((v_hab_env_precalculo = 'S') AND ((v_fec_proxima = v_ult_dia_mes_habil) OR (v_fec_actual = v_ult_dia_mes_habil))) then
     pra_gen_dat_pro_grupal('M',null, null, null, v_dat_pro_grupal);
  end if;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR AL GENERAR LISTADO3. ' || SQLERRM);
END;
/

