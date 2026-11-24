CREATE OR REPLACE TRIGGER IT.TA_PR_CTA_PRESTAMOS
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."PR_CTA_PRESTAMOS"
 FOR EACH ROW
DECLARE
/* Actualizar origen de fondos. */
PROCEDURE LP_ACT_ORI_FONDOS
 (P_COD_ORI_FONDO IN PR_FONDOS.COD_ORI_FONDO%TYPE
 ,P_COD_MONEDA IN PR_FONDOS.COD_MONEDA%TYPE
 ,P_MONTO IN PR_FONDOS.MTO_UTILIZADO%TYPE
 );
PROCEDURE LP_INS_ACT_CUSTODIAS(P_COD_PERSONA IN VARCHAR2,P_NOM_COMPLETO IN VARCHAR2);
   r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
   v_nro_cuenta ge_cuentas.nro_cuenta%type;
   v_fecha      ge_cuentas.fec_cam_estado%type;
   --- Cursor de garantias del credito.
   cursor c_gar_prestamos is
   select cg.nro_cuenta, cg.nro_garantia, cg.mto_aplicado, ga.cod_moneda
     from pr_cta_garantias cg, pr_garantias ga
    where cg.nro_cuenta   = :new.nro_cuenta
      and cg.nro_garantia = ga.nro_garantia
    order by cg.mto_aplicado;
   --- Variables para garantia
   v_cot_mon_ori   ge_cotizaciones.val_conversion%type;
   v_cot_mon_des   ge_cotizaciones.val_conversion%type;
   v_mto_aplicado  pr_cta_garantias.mto_aplicado%type;
   v_mto_garantia  pr_cta_garantias.mto_aplicado%type;
   v_diferencia    pr_cta_prestamos.sal_capital%type;
   v_sal_dif       pr_cta_prestamos.sal_capital%type; --- Saldo de diferencia
   v_cod_val_custodia  cv_val_custodias.cod_val_custodia%type;
   v_cod_persona       ba_personas.cod_persona%type;
/* Actualizar origen de fondos. */
PROCEDURE LP_ACT_ORI_FONDOS
 (P_COD_ORI_FONDO IN PR_FONDOS.COD_ORI_FONDO%TYPE
 ,P_COD_MONEDA IN PR_FONDOS.COD_MONEDA%TYPE
 ,P_MONTO IN PR_FONDOS.MTO_UTILIZADO%TYPE
 )
 IS
v_cod_moneda      pr_fondos.cod_moneda%type;
   v_mto_utilizado   pr_fondos.mto_utilizado%type;
   v_cot_original    ge_cotizaciones.val_conversion%type;
   v_cot_destino     ge_cotizaciones.val_conversion%type;
begin
   --- Llavear registro
   select cod_moneda into v_cod_moneda
     from pr_fondos
    where cod_ori_fondo = p_cod_ori_fondo;
      --for update nowait;
   --- Convertir a moneda del fondo
   pag_gen.pr_con_mon_a_moneda(p_cod_moneda, v_cod_moneda, p_monto, v_mto_utilizado,
                               v_cot_original, v_cot_destino);

   --- Actualizar
   UPDATE pr_fondos
      SET mto_utilizado = nvl(mto_utilizado, 0) + nvl(v_mto_utilizado, 0)
    WHERE cod_ori_fondo = p_cod_ori_fondo;
EXCEPTION
WHEN OTHERS THEN
   if sqlcode = -54 then
      raise_application_error(-20000,
      'Registro de origen de fondos '||p_cod_ori_fondo||' bloqueado por otro usuario.');
    else
      raise;
    end if;
end;
PROCEDURE LP_INS_ACT_CUSTODIAS(P_COD_PERSONA IN VARCHAR2,P_NOM_COMPLETO IN VARCHAR2)
  IS
   v_tip_valor         cv_val_custodias.tip_valor%type;
   v_fec_actual        ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
   v_nro_secuencia     cv_val_cus_movimientos.nro_secuencia%type := 0;
   v_hora              cv_val_cus_movimientos.hora%type := to_char(sysdate,'HH:MI:SS');
   v_ubicacion         cv_val_custodias.ubicacion%type;
   cursor che_custodias is select t.cod_banco,
                                  t.nro_cheque,
                                  t.cta_libradora,
                                  t.cod_moneda,
                                  t.monto,
                                  t.fec_vencimiento,
                                  t.nro_cuota,
                                  nvl(t.cod_persona,p.cod_persona) cod_persona,
                                  fue_obt_nom_persona(nvl(t.cod_persona,p.cod_persona)) nom_persona
                             from ge_che_custodias t,
                                  pr_rel_chq_lib l,
                                  ba_personas p
                            where t.nro_referencia = :new.nro_solicitud
                              and t.tip_servicio = 'D'
                              and t.cod_banco = l.cod_banco(+)
                              and t.nro_cheque = l.nro_cheque(+)
                              and t.cta_libradora = l.cta_libradora(+)
                              and l.cod_tip_documento = p.cod_tip_documento(+)
                              and l.nro_documento = p.nro_documento(+);
   cursor documentos is select d.documento,
                               d.cod_moneda,
                               d.monto,
                               d.nom_completo,
                               d.fec_vencimiento,
                               d.nro_cuota
                          from pr_documentos d
                         where d.nro_referencia = :new.nro_solicitud;
BEGIN
  begin
     select r.val_minimo
       into v_tip_valor
       from ba_cod_referencias r
      where r.dominio = 'TIP_DOC_VAL_CUSTODIA'
        and r.abreviatura is null
        and r.val_maximo = 'I';
   exception
     when no_data_found then
       raise_application_error(-20001,'Tipo de Valor en Custodia no registrado para Pagarés de Préstamos.');
     when others then
       raise_application_error(-20002,'Error al buscar el Tipo de Valor en Custodia.');
   end;
   begin
     select a.cod_val_custodia,a.ubicacion
       into v_cod_val_custodia,v_ubicacion
       from cv_val_custodias a
      where a.nro_operacion = :new.nro_solicitud
        and a.estado = 'I'
        and a.nro_cuota is null;

      update cv_val_custodias c
         set c.estado = 'C',
             c.nro_operacion = :new.nro_cuenta,
             c.fec_cam_estado = v_fec_actual
       where c.cod_val_custodia = v_cod_val_custodia;
   exception
     when no_data_found then
        select s_cod_val_custodia.nextval
          into v_cod_val_custodia
          from dual;
         begin
           insert into cv_val_custodias(cod_val_custodia,tip_valor,cod_moneda,estado,fec_vencimiento,
                                      monto,nro_operacion,cod_ofi_origen,cod_usu_origen,est_etiqueta,fec_est_etiqueta,
                                      cod_persona,Nom_Persona)
                                 values(v_cod_val_custodia,v_tip_valor,:new.cod_moneda,'C',:new.fec_vencimiento,
                                      :new.monto,:new.nro_cuenta,:new.cod_oficina,user,'N',v_fec_actual,
                                      p_cod_persona,p_nom_completo);
         exception
            when others then
               raise_application_error(-20002,'Error al registrar el pagaré en custodia.'||sqlerrm);
         end;
    when others then
       raise_application_error(-20003,'Error al actualizar datos en la custodia.'||sqlerrm);
    end;

    begin
       v_nro_secuencia :=  nvl(v_nro_secuencia,0) + 1;
       v_hora              := pag_gen.fu_obt_sig_segundo(v_hora);
       insert into cv_val_cus_movimientos(fecha,
                                 hora,
                                 cod_usuario,
                                 nro_secuencia,
                                 monto,
                                 cod_val_custodia,
                                 cod_moneda,
                                 est_custodia,
                                 tipo,
                                 estado,
                                 reversado,
                                 ubicacion)
                          values(v_fec_actual,
                                 v_hora,
                                 user,
                                 v_cod_val_custodia,
                                 ---v_nro_secuencia,
                                 :new.monto,
                                 v_cod_val_custodia,
                                 :new.cod_moneda,
                                 'C',
                                 1,
                                 'N',
                                 'N',
                                 v_ubicacion);
     exception
          when others then
            raise_application_error(-20003,'Error al registrar el pagaré en custodia.'||sqlerrm);
     end;

    if fup_obt_tip_descuento(:new.cod_modalidad) in('C','D') then
       begin
         select r.val_minimo
           into v_tip_valor
           from ba_cod_referencias r
          where r.dominio = 'TIP_DOC_VAL_CUSTODIA'
            and instr(','||r.abreviatura||',',','||:new.cod_modalidad||',') > 0
            and r.val_maximo = 'I';
       exception
         when no_data_found then
           raise_application_error(-20003,'Tipo de Valor en Custodia no registrado para Pagarés de Préstamos.');
         when others then
           raise_application_error(-20004,'Error al buscar el Tipo de Valor en Custodia.'||sqlerrm);
       end;
       if fup_obt_tip_descuento(:new.cod_modalidad) = 'C' then
          for che in che_custodias loop

            select s_cod_val_custodia.nextval
              into v_cod_val_custodia
              from dual;

            begin
              insert into cv_val_custodias(cod_val_custodia,tip_valor,cod_moneda,estado,fec_vencimiento,
                                           monto,cod_persona,nom_persona,nro_operacion,nro_cuota,
                                           cod_banco,nro_valor,cta_libradora,cod_ofi_origen,cod_usu_origen,
                                           est_etiqueta,fec_est_etiqueta)
                                    values(v_cod_val_custodia,v_tip_valor,che.cod_moneda,'C',che.fec_vencimiento,
                                           che.monto,che.cod_persona,che.nom_persona,:new.nro_cuenta,che.nro_cuota,
                                           che.cod_banco,che.nro_cheque,che.cta_libradora,:new.cod_oficina,user,
                                           'N',v_fec_actual);

               v_nro_secuencia := v_nro_secuencia + 1;
               v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);

              insert into cv_val_cus_movimientos(fecha,
                                                   hora,
                                                   cod_usuario,
                                                   nro_secuencia,
                                                   monto,
                                                   cod_val_custodia,
                                                   cod_moneda,
                                                   est_custodia,
                                                   tipo,
                                                   estado,
                                                   cod_banco,
                                                   reversado,
                                                   nro_referencia)
                                            values(v_fec_actual,
                                                   v_hora,
                                                   user,
                                                   v_cod_val_custodia,
                                                   --v_nro_secuencia,
                                                   :new.monto,
                                                   v_cod_val_custodia,
                                                   :new.cod_moneda,
                                                   'C',
                                                   1,
                                                   'N',
                                                   che.cod_banco,
                                                   'N',
                                                   che.nro_cheque);
           exception
             when others then
               raise_application_error(-20002,'Error al insertar el Cheque en Custodia.'||sqlerrm);
           end;
         end loop;
      elsif fup_obt_tip_descuento(:new.cod_modalidad) = 'D' then
         for doc in documentos loop
            select s_cod_val_custodia.nextval
              into v_cod_val_custodia
              from dual;

            begin
              insert into cv_val_custodias(cod_val_custodia,tip_valor,cod_moneda,estado,fec_vencimiento,
                                           monto,nro_operacion,nro_cuota,nro_valor,cod_ofi_origen,
                                           cod_usu_origen,est_etiqueta,fec_est_etiqueta,cod_persona,nom_persona)
                                    values(v_cod_val_custodia,v_tip_valor,doc.cod_moneda,'C',doc.fec_vencimiento,
                                           doc.monto,:new.nro_cuenta,doc.nro_cuota,doc.documento,:new.cod_oficina,
                                           user,'N',v_fec_actual,p_cod_persona,p_nom_completo);

              v_nro_secuencia := v_nro_secuencia + 1;
               v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);

              insert into cv_val_cus_movimientos(fecha,
                                                   hora,
                                                   cod_usuario,
                                                   nro_secuencia,
                                                   monto,
                                                   cod_val_custodia,
                                                   cod_moneda,
                                                   est_custodia,
                                                   tipo,
                                                   estado,
                                                   reversado,
                                                   nro_referencia)
                                            values(v_fec_actual,
                                                   v_hora,
                                                   user,
                                                   v_cod_val_custodia,
                                                   --v_nro_secuencia,
                                                   :new.monto,
                                                   v_cod_val_custodia,
                                                   :new.cod_moneda,
                                                   'C',
                                                   1,
                                                   'N',
                                                   'N',
                                                   doc.documento);
            exception
              when others then
                raise_application_error(-20003,'Error al insertar en Documento en Custodia.'||sqlerrm);
            end;
         end loop;
      end if;
    end if;
END;
BEGIN
   if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'PRP_DEV_PRE_FIN' then --si se está ejecutando el devengado diario no debe entrar
     --- Registro en GE_CUENTAS
     r_gcuen.nro_cuenta := :new.nro_cuenta;
     v_nro_cuenta := :new.nro_cuenta;
     r_gcuen.dig_verificador := :new.dig_verificador;
     IF inserting THEN
       --- Recuperar el cliente del la solicitud de la cuenta
       BEGIN
         select p.nom_completo,p.cod_persona
           into r_gcuen.denominacion,v_cod_persona
           from pr_solicitudes s, ba_personas p
          where s.nro_solicitud = :new.nro_solicitud
            and s.cod_persona =  p.cod_persona;
       EXCEPTION
         when no_data_found then
           r_gcuen.denominacion := 'SIN SOLICITUD';
       END;
     ELSIF updating THEN
       --- Recuperar nombre completo de cliente principal
       BEGIN
         select p.nom_completo,p.cod_persona
           into r_gcuen.denominacion,v_cod_persona
           from ge_cta_clientes g, ba_personas p
          where g.nro_cuenta = :new.nro_cuenta
            and g.cod_persona = p.cod_persona
            and g.relacion = 'P';
       EXCEPTION
         when no_data_found then
           r_gcuen.denominacion := 'SIN CLIENTE PRINCIPAL';
         when too_many_rows then
           raise_application_error(-20000,
         'Mas de un registro '||:new.nro_cuenta);
       END;
     END IF;
     r_gcuen.cod_modulo        := :new.cod_modulo;
     r_gcuen.cod_modalidad     := :new.cod_modalidad;
     r_gcuen.cod_oficina       := :new.cod_oficina;
     r_gcuen.estado            := :new.estado;
     IF :new.estado <> :old.estado OR
        inserting THEN
       r_gcuen.fec_cam_estado := pag_cal.fu_obt_fec_actual(6);
     END IF;
     r_gcuen.cod_moneda        := :new.cod_moneda;
     r_gcuen.fec_apertura      := :new.fec_inicio;
     r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
     r_gcuen.tas_personalizada := 'N';
     r_gcuen.tra_prohibida     := 'N';
     r_gcuen.sal_contable      := nvl( :new.sal_capital, :new.mto_capital );
     r_gcuen.fre_extracto      := 'M';
     r_gcuen.ret_personalizada := 'N';
     r_gcuen.val_tasa          := :new.val_tasa;
     r_gcuen.dia_atraso        := :new.dia_atraso;
     r_gcuen.max_atraso        := :new.max_atraso;
     r_gcuen.pro_atraso        := :new.pro_atraso;
     r_gcuen.mto_mora          := :new.mto_mora;
     r_gcuen.en_juicio         := :new.en_juicio;
     r_gcuen.fec_juicio        := :new.fec_juicio;
     r_gcuen.cod_ent_juicio    := :new.cod_ent_juicio;
     r_gcuen.est_verificacion  := 'V';
      if inserting then
         --- Insertar tabla de Cuentas
         PAA_CTA.PRA_INS_GE_CUENTAS(r_gcuen);
          if fue_ver_mod_implementado(31) = 'S' then
             LP_INS_ACT_CUSTODIAS(v_cod_persona,r_gcuen.denominacion);
         end if;
      elsif updating then
         --- Actualizar datos en Cuentas
         v_nro_cuenta := :old.nro_cuenta;
         PAA_CTA.PRA_UPD_GE_CUENTAS(v_nro_cuenta, r_gcuen);
      elsif deleting then
        --Borrar..
         Delete
         from GE_CUENTAS
         where nro_cuenta = :old.nro_cuenta;
      end if;
      --- Actualizar origen de fondos
      if updating then
         if  :old.cod_ori_fondo <> :new.cod_ori_fondo then
            lp_act_ori_fondos(:new.cod_ori_fondo, :new.cod_moneda, :old.sal_capital);
            lp_act_ori_fondos(:old.cod_ori_fondo, :new.cod_moneda, :old.sal_capital*-1);
         end if;
      end if;
   end if;
END;
/
