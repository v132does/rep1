CREATE OR REPLACE PROCEDURE IT.PRB_ENV_MAI_PER_NUEVO is
 -- Envia clientes nuevos automaticos por mail a gestores comerciales
  v_nro_cuenta_ant   varchar2(15);
  v_asunto           varchar2(100);
  v_contenido        long;--varchar2(3000);
  --DYDMR-2777 HD - Clientes Nuevos CRC SC 24247
  --v_dir_correo_de    varchar2(100) := 'backderiesgos@bbva.com.py';
  v_dir_correo_de    varchar2(100) := fug_obt_pardinamico('MAIL_COLOCACIONES');
  v_dir_correo_para  varchar2(100);
  v_fec_anterior     date;

  conn               utl_smtp.connection;
  v_det_error varchar2(100);

 ---trae clientes nuevos que no están registrados en CRC
	    CURSOR c_per_nuevo IS
      select p.cod_persona, p.nom_completo, t.abreviatura, p.nro_documento,
      e.nro_cuenta, e.cod_modalidad, m.descripcion des_modal, e.relacion, o.abreviatura relacion_desc,
      c.fec_apertura, e.cod_oficina,l.cod_usu_oficial,
      nvl(FUG_OBT_NOM_CRC(l.cod_usu_oficial,u.cod_oficina),'SIN CORREO')oficial,
      --nvl(FUG_OBT_DIR_MAIL_CRC(l.cod_usu_oficial,u.cod_oficina),'backderiesgos@bbva.com.py')mail_gestor
      nvl(FUG_OBT_DIR_MAIL_CRC(l.cod_usu_oficial,u.cod_oficina),v_dir_correo_de)mail_gestor
       from ge_cta_clientes e, ge_cuentas c, ba_personas p, ba_tip_documentos t,
       ge_modalidades m, ge_clientes l, ba_usuarios u,
       ba_cod_referencias o,ge_cla_operaciones ge
      where c.nro_cuenta=e.nro_cuenta
      and p.cod_persona=e.cod_persona
      and e.relacion=o.val_minimo
      and o.dominio='RELACION'
      and e.relacion in ('P','C') -- Solo principal y codeudores
      and p.cod_tip_documento=t.cod_tip_documento
      --and c.fec_apertura = v_fec_actual -- No debe validar
      and m.cod_modulo=c.cod_modulo
      and m.cod_modalidad=c.cod_modalidad
      and l.cod_persona=e.cod_persona
      and l.cod_usu_oficial=u.cod_usuario
      and ge.nro_cuenta=c.nro_cuenta
      and nvl(ge.tot_deu_real,0) + nvl(ge.tot_deu_contingente,0) <> 0 -- Que tenga deuda
      and not exists(select 1 from personas_ref r
      where r.rf_tipo_ident=t.abreviatura
      and r.rf_numero=p.nro_documento)
      and not exists(select 1 from ge_cla_operaciones_his h where h.nro_cuenta=ge.nro_cuenta
      and h.fecha=v_fec_anterior)
      and e.cod_modulo in (3,4,5,6,8,15) --PCCDEEVO-151
      order by c.nro_cuenta;

      ---Para los cod_persona relacionados a un mismo nro de cuenta
       CURSOR c_cliente(p_nro_cuenta IN VARCHAR2) IS
       select p.cod_persona, p.nom_completo, t.abreviatura, p.nro_documento,
            e.nro_cuenta, e.cod_modalidad, m.descripcion des_modal, e.relacion, o.abreviatura relacion_desc,
            c.fec_apertura, e.cod_oficina, l.cod_usu_oficial,u.nombre oficial,
            fug_obt_dir_mail_usu(l.cod_usu_oficial)mail_gestor
             from ge_cta_clientes e, ge_cuentas c, ba_personas p, ba_tip_documentos t, ge_modalidades m, ge_clientes l, ba_usuarios u,
                  ba_cod_referencias o,ge_cla_operaciones ge
        where c.nro_cuenta=e.nro_cuenta
        and p.cod_persona=e.cod_persona
        and e.relacion=o.val_minimo
        and o.dominio='RELACION'
        and e.relacion in ('P','C') -- Solo principal y codeudores
        and p.cod_tip_documento=t.cod_tip_documento
        --and c.fec_apertura = v_fec_actual
        and m.cod_modulo=c.cod_modulo
        and m.cod_modalidad=c.cod_modalidad
        and l.cod_persona=e.cod_persona
        and l.cod_usu_oficial=u.cod_usuario
        and ge.nro_cuenta=c.nro_cuenta
        and nvl(ge.tot_deu_real,0) + nvl(ge.tot_deu_contingente,0) <> 0 -- Que tenga deuda
        and not exists(select 1 from personas_ref r
        where r.rf_tipo_ident=t.abreviatura
        and r.rf_numero=p.nro_documento)
        and not exists(select 1 from ge_cla_operaciones_his h where h.nro_cuenta=ge.nro_cuenta
        and h.fecha=v_fec_anterior)
        and e.nro_cuenta=p_nro_cuenta
        and e.cod_modulo in (3,4,5,6,8,15) --PCCDEEVO-151
        order by c.nro_cuenta;


begin

    v_asunto       := 'Clientes Nuevos CRC';
    v_nro_cuenta_ant:='1';
    v_fec_anterior:=pag_cal.FU_OBT_FEC_ANTERIOR(1);

 begin

     FOR reg IN c_per_nuevo LOOP
        v_dir_correo_para:=reg.mail_gestor||','||v_dir_correo_de/*||',vpalomar@bbva.com.py'*/;--Se excluye a pedido de Victor Palomar

       if v_nro_cuenta_ant <>reg.nro_cuenta then
         v_contenido:='Sr/a'||chr(9)||reg.oficial||chr(10)||'Rogamos se sirva escanear el Documento de Identidad (CI, Carné de Residencia Permanente, Pasaporte) y/o RUC de los siguientes Clientes afectados a'
		     ||chr(9)||reg.des_modal||chr(9)||'Nro Cuenta:'||chr(9)||reg.nro_cuenta||',adjuntándolo finalmente al presente para su posterior remisión al resto de copiados en el presente correo electrónico, en plazo máximo de 24Hs de recibido el referido.'
         ||chr(10)||'Detalle de Clientes';

         for reg2 in c_cliente(reg.nro_cuenta) loop
            v_contenido:=v_contenido||chr(10)||'Cliente'||chr(9)||reg2.nom_completo||
            chr(9)||'Cliente Nro'||chr(9)||reg2.cod_persona||chr(9)||'aún no informado al CRC';
         end loop;
         v_nro_cuenta_ant:=reg.nro_cuenta;
         v_contenido:=v_contenido||chr(10)||chr(10)||'Cordial Saludo'||chr(10)||'Gestion de Reportes Automáticos a la CRC';
         ---envia el mail al gestor correspondiente
         it_mail.mail_attach(v_dir_correo_de,--sender
                             v_dir_correo_para, --destinatario/s
                             v_asunto, --asunto correo
                             v_asunto, --mensaje correo
                             v_contenido, --data
                             null --nombre del archivo
                             );   
        end if;
		END LOOP;              
	exception

      when utl_smtp.transient_error or utl_smtp.permanent_error then
      begin
        utl_smtp.quit(conn);
      exception
      when utl_smtp.transient_error or utl_smtp.permanent_error then
        null;
      end;
      v_det_error := substr(sqlerrm,1,4000);
      end;
--
  commit;
--

exception
  when others then
    raise_application_error(-20000,'Error al Generar mail. '||sqlerrm);
end;
/

