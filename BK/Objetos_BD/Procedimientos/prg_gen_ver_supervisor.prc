create or replace procedure it.prg_gen_ver_supervisor is
  -- Variables locales
   v_cod_usuario       ba_usuarios.cod_usuario%type  := 'AGF';
   v_dir_correo        ba_usuarios.dir_correo%type   := 'afalk@itbank.com.py';
   v_cod_actividad     cr_agendas.cod_actividad%type := 3;
   v_cod_mot_actividad cr_agendas.cod_mot_actividad%type := 21;
   v_fec_actual        ge_calendarios.fec_actual%type;
   v_det_actividad     cr_agendas.det_actividad%type;
   v_dir_cor_varios    varchar2(300);
   -- personas no verificadas en la fecha
   Cursor per is
           Select pe.cod_persona, ag.cod_usu_encargado, us.dir_correo, cl.cod_oficina, cl.cod_usu_oficial
             from ba_usuarios us, ba_oficinas ag, ge_clientes cl, ba_personas pe
            where us.cod_usuario(+) = ag.cod_usu_encargado
              and cl.cod_persona = pe.cod_persona
              and ag.cod_oficina = cl.cod_oficina
              and est_verificacion = 'N'
              and trunc(pe.fec_modificacion) = v_fec_actual;
   -- cuentas no verificadas en la fecha
   Cursor cta is
           Select ct.nro_cuenta, cc.cod_persona, ag.cod_usu_encargado, us.dir_correo, cl.cod_oficina, cl.cod_usu_oficial
             from ba_usuarios us, ba_oficinas ag, ge_clientes cl, ge_cta_clientes cc, ge_cuentas ct
            where us.cod_usuario(+) = ag.cod_usu_encargado
              and cl.cod_persona = cc.cod_persona
              and ag.cod_oficina = cl.cod_oficina
              and cc.nro_cuenta = ct.nro_cuenta
              and cc.relacion = 'P'
              and est_verificacion = 'N'
              and trunc(ct.fec_modificacion) = v_fec_actual;
   -- No impresion de cda y cupones envio de mail a operativo, oficial y auditoria
   Cursor cda is
          Select ct.nro_cuenta, ct.beneficiario, ct.fec_apertura, ct.fec_vencimiento,
                 ct.cod_moneda, ct.capital, cod_usu_verificador, cod_usu_oficial,
                 ct.est_certificado, nvl(cup_no_emitidos,0) cup_no_emitidos,
                 ct.serie, ct.nro_certificado
            from ge_clientes d,ge_cta_clientes c,ge_cuentas b, ah_cta_certificados ct,
                (select nro_cuenta cup_cuenta, count(*) cup_no_emitidos
                   from ah_cupones
                  where estado = 'C'
                  group by nro_cuenta)
           where b.nro_cuenta = ct.nro_cuenta
             and b.est_verificacion = 'V'
             and b.fec_verificacion = v_fec_actual + 1  -- se suma uno para tomar los de hoy
             and c.nro_cuenta = ct.nro_cuenta
             and c.relacion = 'P'
             and d.cod_persona = c.cod_persona
             and cup_cuenta(+) = ct.nro_cuenta
             and (ct.est_certificado = 'C' or nvl(cup_no_emitidos,0) > 0);
   --- Insertar actividad en agenda
   PROCEDURE LP_INS_AGENDA
     (p_cod_persona in ge_cta_clientes.cod_persona%type
     ,p_det_actividad in cr_agendas.det_actividad%type
     ,p_cod_usuario in ba_usuarios.cod_usuario%type
     ,p_dir_correo  in ba_usuarios.dir_correo%type
     ) IS
   BEGIN
      --- Generar agenda al verificador
      insert into cr_agendas
        (cod_agenda, cod_persona, cod_usu_encargado,
         cod_actividad, cod_estado, cod_mot_actividad, fec_actividad,
         det_actividad)
      values
        (s_cod_agenda.nextval, p_cod_persona, p_cod_usuario,
         v_cod_actividad, 1, v_cod_mot_actividad, pag_cal.FU_OBT_FEC_ACTUAL(3),
         p_det_actividad
      );
      --- Enviar mail al verificador
      if p_dir_correo is not null then
         it_mail.mail(fug_obt_dir_correo,
                      p_dir_correo,
                      'Verificacion no realizada en Plazo',
                      p_det_actividad);
      end if;
   END;
begin
  --Se le resta 1 dia porque no debe generar e-mail por los pendientes del dia 28/04/2005 JCLG
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3)-1;
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=3; END;

  --Se agrega en el e-mail el oficial y la oficina segun requerimiento 474
	for r_per in per Loop
     v_det_actividad := 'No se realizó la verificación de la persona: '
		 ||r_per.cod_persona||' Oficina: '||to_char(r_per.cod_oficina)||' Oficial: '||r_per.cod_usu_oficial||'. Favor verificar.';
     if r_per.cod_usu_encargado is not null then
        lp_ins_agenda(r_per.cod_persona,
           v_det_actividad,
           r_per.cod_usu_encargado, r_per.dir_correo);
     end if;
     -- Asigna al auditor
     it_mail.mail(fug_obt_dir_correo,
                  v_dir_correo,
                  'Verificacion no realizada en Plazo',
                  v_det_actividad);
  End Loop;

	--Se agrega en el e-mail el oficial y la oficina segun requerimiento 474
  for r_cta in cta Loop
     v_det_actividad := 'No se realizó la verificación de la cuenta: '
		 ||r_cta.nro_cuenta||' Oficina: '||to_char(r_cta.cod_oficina)||' Oficial: '||r_cta.cod_usu_oficial||'. Favor verificar.';
     if r_cta.cod_usu_encargado is not null then
        lp_ins_agenda(r_cta.cod_persona,
        v_det_actividad,
        r_cta.cod_usu_encargado, r_cta.dir_correo);
     end if;
     -- Asigna al auditor
     it_mail.mail(fug_obt_dir_correo,
                  v_dir_correo,
                  'Verificacion no realizada en Plazo',
                  v_det_actividad);
  End Loop;

	--Cdas y/o cupones sin emitir. Se envia mail al operativo, oficial y auditoria
  for r_cda in cda Loop
     v_det_actividad := 'No se ha realizado la impresión de';
     if r_cda.est_certificado = 'C' then
        v_det_actividad := v_det_actividad ||'l Carton Nro '||r_cda.serie||' '||r_cda.nro_certificado;
        if r_cda.cup_no_emitidos > 0 then
           v_det_actividad := v_det_actividad||'  y de';
        end if;
     end if;
     if r_cda.cup_no_emitidos > 0 then
        v_det_actividad := v_det_actividad||' '||r_cda.cup_no_emitidos||' cupon(es) de CDA ';
     end if;
     v_det_actividad := v_det_actividad||chr(10)||'correspondiente(s) a la Cuenta '||r_cda.nro_cuenta||' abierta el dia '||
     to_char(r_cda.fec_apertura,'dd/mm/yyyy')||','||chr(10)||'cuyo beneficiario es '||r_cda.beneficiario||chr(10)||
     chr(10)||'Atentamente.';
     -- envia el e-mail
     v_dir_cor_varios := v_dir_correo; -- auditor
     if r_cda.cod_usu_verificador is not null then  -- se agrega el mail del operativo que verifico la cuenta
        v_dir_cor_varios := trim(v_dir_cor_varios||';'||trim(fug_obt_dir_mail_usu(r_cda.cod_usu_verificador)));
     end if;
     if r_cda.cod_usu_oficial is not null then -- se agrega el mail del oficial
        if substr(v_dir_cor_varios,length(v_dir_cor_varios),1) <> ';' then
           v_dir_cor_varios := v_dir_cor_varios||';';
        end if;
        v_dir_cor_varios := v_dir_cor_varios||trim(fug_obt_dir_mail_usu(r_cda.cod_usu_oficial));
     end if;
     it_mail.mail(fug_obt_dir_correo,
                  v_dir_cor_varios,
                  'Impresion de Cartones de CDA y/o Cupones no realizada',
                  v_det_actividad);
  End Loop;
end prg_gen_ver_supervisor;
/

