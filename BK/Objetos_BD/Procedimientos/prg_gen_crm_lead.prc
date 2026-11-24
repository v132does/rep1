CREATE OR REPLACE PROCEDURE IT.PRG_GEN_CRM_LEAD (p_cod_persona   ba_personas.cod_persona%type,
                                              p_cod_tip_lead  ge_crm_leads.cod_tip_lead%type,
                                              p_cod_canal     ge_canales.cod_canal%type default null,
                                              p_cod_modulo    ba_modulos.cod_modulo%type default null,
                                              p_cod_modalidad ge_modalidades.cod_modalidad%type default null,
                                              p_cod_campana   cr_campanas.cod_campana%type default null,
                                              p_nro_solicitud ta_solicitudes.nro_solicitud%type default null,
                                              p_lin_aprobada  GE_CLI_APROBADOS_ATM.Lin_Aprobada%type default null,
                                              p_afinidad      ge_cli_aprobados_atm.afinidad%type default null,
                                              p_cod_producto  varchar2 default null)

 IS
  v_mail_remitente     ba_mails.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
  v_mail_crm           ba_mails.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_CRM');--'crm_solicitudprod@bbva.com.py';
  v_asunto             varchar2(500);
  v_inf_adicional      varchar2(4000);
  v_cod_crm_lead       ge_crm_leads.cod_crm_lead%type := s_cod_crm_lead.nextval;
  v_nro_documento      ba_personas.nro_documento%type;
  v_cod_oficina        ge_clientes.cod_oficina%type;

BEGIN
  BEGIN pre_ini_aplicacion; PAE_CNF.G_COD_MODULO:=1;END;

  v_nro_documento := fue_obt_nro_doc_persona(p_cod_persona);
  v_cod_oficina   := fug_obt_ofi_cliente(p_cod_persona);
  
  --mis productos
  if p_cod_producto = fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_PRESTAMOS') then
     v_asunto        := v_nro_documento||'|'||to_char(sysdate,'YYYYMMDD HHMMSS')||'*'||p_cod_canal||'*;1;-ATM';--cambiar codigo por producto
     v_inf_adicional := ' NOMBRE CLIENTE: '||fue_obt_nom_persona(P_COD_PERSONA)||chr(13)||
                        'INTERESADO EN PRODUCTO: '||fug_obt_des_modalidad(p_cod_modalidad)||chr(13)||
                        'CANAL: '||fug_obt_des_canal(p_cod_canal)||chr(13);
                        --'NRO SOLICITUD: '||p_nro_solicitud||chr(13)||
                        --'LINEA APROBADA: '||p_lin_aprobada||chr(13)||
                        --'AFINIDAD: '||p_afinidad;
  elsif p_cod_producto = fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_TARJETAS') then
     v_asunto        := v_nro_documento||'|'||to_char(sysdate,'YYYYMMDD HHMMSS')||'*'||p_cod_canal||'*;3;-ATM';
     v_inf_adicional := ' NOMBRE CLIENTE: '||fue_obt_nom_persona(P_COD_PERSONA)||chr(13)||
                        'INTERESADO EN PRODUCTO: Tarjeta de Credito'||chr(13)||
                        'CANAL: '||fug_obt_des_canal(p_cod_canal)||chr(13);
                        --'NRO SOLICITUD: '||p_nro_solicitud||chr(13)||
                        --'LINEA APROBADA: '||p_lin_aprobada||chr(13)||
                        --'AFINIDAD: '||p_afinidad;
  elsif p_cod_producto = fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_SEGUROS') then
     v_asunto        := v_nro_documento||'|'||to_char(sysdate,'YYYYMMDD HHMMSS')||'*'||p_cod_canal||'*;4;-ATM';
     v_inf_adicional := ' NOMBRE CLIENTE: '||fue_obt_nom_persona(P_COD_PERSONA)||chr(13)||
                        'INTERESADO EN PRODUCTO: '||'SEGURO CONTRA ROBO EN CAJEROS'||chr(13)||
                        'CANAL: '||fug_obt_des_canal(p_cod_canal)||chr(13);
                        --'NRO SOLICITUD: '||p_nro_solicitud||chr(13)||
                        --'LINEA APROBADA: '||p_lin_aprobada||chr(13)||
                        --'AFINIDAD: '||p_afinidad;
  else
     --para tarjetas aceptadas
     v_asunto        := v_nro_documento||'|'||to_char(sysdate,'YYYYMMDD HHMMSS')||'*'||p_cod_canal||'*;3;-ATM';
     v_inf_adicional := ' NOMBRE CLIENTE: '||fue_obt_nom_persona(P_COD_PERSONA)||chr(13)||
                        'PRODUCTO ACEPTADO: '||fug_obt_des_modalidad(p_cod_modalidad)||chr(13)||
                        'CANAL: '||fug_obt_des_canal(p_cod_canal)||chr(13)||
                        'NRO SOLICITUD: '||p_nro_solicitud||chr(13)||
                        'LINEA APROBADA: '||p_lin_aprobada||chr(13)||
                        'AFINIDAD: '||p_afinidad;
  end if;
  begin
    it_mail.mail(v_mail_remitente,
                v_mail_crm,
                v_asunto,
                v_inf_adicional);
  exception
    when others then

       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
       values (v_mail_remitente, v_mail_crm, v_asunto, v_inf_adicional, sysdate, user)  ;
  end;

  insert into ge_crm_leads(cod_crm_lead, cod_persona, nro_documento, cod_oficina, cod_canal, cod_campana, fec_alt_crm, cod_modulo, cod_modalidad, cod_tip_lead, dat_asunto, dat_adicional)
  values (v_cod_crm_lead, p_cod_persona, v_nro_documento, v_cod_oficina, p_cod_canal, p_cod_campana, sysdate, p_cod_modulo, p_cod_modalidad, p_cod_tip_lead, v_asunto, v_inf_adicional);

exception
    when others then
      PRG_INS_LOG_ERRORES('PRG_GEN_CRM_LEAD',SQLERRM);
END;
/

