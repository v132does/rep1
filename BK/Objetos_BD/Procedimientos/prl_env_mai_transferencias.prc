create or replace procedure it.prl_env_mai_transferencias(p_nro_operacion in number, p_cod_usuario in varchar2 default null, p_fec_envio in date default null, p_hor_envio in varchar2 default null) IS
--Variables--
 v_dir_correo_ent varchar2(4000) := FUG_OBT_DIR_MAIL_USU(nvl(p_cod_usuario,user));
 v_dir_correo varchar2(4000);
 v_fec_envio date := p_fec_envio;
 v_hor_envio varchar2(8) := p_hor_envio;
 v_cod_persona ba_personas.cod_persona%type;
--Cursores--
 cursor c_transferencia is
 select * from lc_transferencias a
  where a.nro_operacion = p_nro_operacion;
BEGIN
if v_fec_envio is null then
   v_fec_envio := pag_cal.FU_OBT_FEC_ACTUAL(7);
end if;
if v_hor_envio is null then
   v_hor_envio := to_char(sysdate,'hh24:mi:ss');
end if;
for det in c_transferencia loop
    if det.cod_modalidad = 72 then
       v_cod_persona := det.cod_per_solicitante;
    elsif det.cod_modalidad = 75 then
       v_cod_persona := det.cod_per_beneficiario;
    end if;
    v_dir_correo := ful_obt_ema_transferencias(v_cod_persona, det.cod_oficina, det.cod_modalidad);
    if v_dir_correo is not null  and v_dir_correo_ent is not null then
       if det.cod_modalidad = 72 then --Transferencias Emitidas--
          it_mail.mail(v_dir_correo_ent, v_dir_correo,
                      'SWIFT: '||det.nom_solicitante||' '||det.cod_moneda||':'||rtrim(ltrim(to_char(det.monto,'999,999,999,990.00')))||' Ref.Operacion: '||rtrim(ltrim(to_char(p_nro_operacion))),
                       det.msj_swift);
       elsif det.cod_modalidad = 75 then --Transferencias Recibidas--
          it_mail.mail(v_dir_correo_ent,  v_dir_correo,
                       'TRANSF.REC: '||det.nom_beneficiario||' '||det.cod_moneda||':'||trim(to_char(det.monto,'999,999,999,990.00')),
                       'Sr/a '||det.nom_beneficiario||chr(13)||
                       ' Le informamos que hemos recibido una transferencia del exterior bajo ref. '||det.nro_ref_externa||chr(13)||
                       ' por el monto de '||det.cod_moneda||' '||ltrim(to_char(det.monto))||'.-'||' La misma  ha sido acreditada en su cuenta Nro. '||det.nro_cta_referencia||', previa' ||chr(13)||
                       ' deducción de la comisión acordada y fue enviada por '||det.nom_solicitante|| ' desde '||fue_obt_des_pais(det.cod_pai_solicitante)||'.'||chr(13)||
                       ' Observación: '||det.observacion||chr(13)||'Mensaje Swift:'||chr(13)||det.msj_swift);
       end if;
       insert into lc_mai_transferencias_log
       (nro_operacion, dir_envio, fec_envio, hor_envio, cod_modalidad)
       values
       (p_nro_operacion, v_dir_correo, v_fec_envio, v_hor_envio, det.cod_modalidad);
   end if;
end loop;

end prl_env_mai_transferencias;
/

