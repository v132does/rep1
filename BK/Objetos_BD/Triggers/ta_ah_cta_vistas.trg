CREATE OR REPLACE TRIGGER IT.TA_AH_CTA_VISTAS
 AFTER DELETE OR INSERT OR UPDATE 
 ON AH_CTA_VISTAS
 FOR EACH ROW

DECLARE
r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;
v_est_modulo ba_modulos.estado%type;
v_cod_persona ba_personas.cod_persona%type;
v_tip_persona ba_personas.tipo%type;
v_tip_extracto ge_clientes.tip_extracto%type;
BEGIN
 if user <> fue_obt_des_refcodes('USU_CIERRE',user) or user = 'APICAJERO' then 
   IF inserting OR updating THEN
      r_gcuen.nro_cuenta        := :new.nro_cuenta;
      v_nro_cuenta              := :new.nro_cuenta;
      r_gcuen.dig_verificador   := :new.dig_verificador;
      r_gcuen.denominacion      := :new.denominacion;
      r_gcuen.cod_modulo        := :new.cod_modulo;
      r_gcuen.cod_modalidad     := :new.cod_modalidad;
      r_gcuen.cod_oficina       := :new.cod_oficina;
      r_gcuen.estado            := :new.estado;
      r_gcuen.fec_cam_estado    := :new.fec_cam_estado;
      r_gcuen.sal_contable      := nvl(:new.sal_total,0)-nvl(:new.sal_retenido,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_apertura;
      r_gcuen.cod_tasa          := :new.cod_tasa;
      r_gcuen.fre_extracto      := :new.fre_extracto;
      r_gcuen.tas_personalizada := :new.tas_personalizada;
      r_gcuen.tra_prohibida     := :new.tra_prohibida;
      r_gcuen.ret_personalizada := :new.ret_personalizada;
      r_gcuen.cod_cau_cancelacion := :new.cod_cau_cancelacion;
      r_gcuen.cod_sub_modalidad := :new.cod_sub_modalidad;
   END IF;
   IF inserting THEN
      --- Insertar tabla de Cuentas
      PAA_CTA.PRA_INS_GE_CUENTAS(r_gcuen);
   ELSIF updating THEN
      IF :old.nro_cuenta <> :new.nro_cuenta THEN
         v_nro_cuenta := :old.nro_cuenta;
      END IF;
      --si modifica la firma o el mínimo pactado
      IF :new.reg_firma <> nvl(:old.reg_firma,'x') OR
    nvl(:new.cta_combinada,'X') <> NVL(:old.cta_combinada,'X') OR
    nvl(:new.sal_minimo,0) <> nvl(:old.sal_minimo,0) OR
    nvl(:new.denominacion,'X') <> nvl(:old.denominacion,'X') THEN
         r_gcuen.est_verificacion := 'N'; -- sin verificar
      END IF;
      IF NVL(:NEW.MTO_DEB_PENDIENTES,0) <> NVL(:OLD.MTO_DEB_PENDIENTES,0) OR
         NVL(:NEW.MTO_CRE_PENDIENTES,0) <> NVL(:OLD.MTO_CRE_PENDIENTES,0) THEN
         NULL; -- no se debe actualizar para no bloquear el atm, porque es cierre. 
      ELSE   
         PAA_CTA.PRA_UPD_GE_CUENTAS(v_nro_cuenta, r_gcuen);
      END IF;
      
      if :new.estado <> :old.estado and :new.estado = 'N' then
        Begin
           select g.cod_persona, p.tipo
             into v_cod_persona, v_tip_persona
             from ge_cta_clientes g, ba_personas p
            where g.nro_cuenta = :new.nro_cuenta
              and g.relacion = 'P'
              and g.cod_persona = p.cod_persona;
        Exception
          when no_data_found then
            v_cod_persona := null;
            v_tip_persona := null;
        end;
        
        begin
          select tip_extracto
            into v_tip_extracto
            from ge_clientes
           where cod_persona = v_cod_persona;
       exception 
         when others then
           v_tip_extracto := null;
       end;
       
       if nvl(v_tip_extracto, 'x') <> 'N' and nvl(v_tip_persona, 'x') = 'F' then
          begin
            update ge_clientes               set tip_extracto = 'N'
             where cod_persona = v_cod_persona;
          exception
            when others then
              raise_application_error(-20000, 'No se puede actualizar el Tipo de Extracto. '||sqlerrm);        
          end;
          prg_gen_not_extracto('ITGF', 'N', :new.cod_modulo, :new.nro_cuenta, v_cod_persona, null);
        end if;   
      end if;
      --PCCREPAN-3 Mejoras Pago de Nómina Fase 1 - Proceso de Altas
      IF nvl(:new.cod_ente,-1) <> nvl(:old.cod_ente,-1) THEN
       Begin
          select cod_persona
            into v_cod_persona
            from ge_cta_clientes g
           where g.nro_cuenta = :old.nro_cuenta
             and g.relacion = 'P';
        Exception
          when no_data_found then
            v_cod_persona := null;
        end;
        insert into ge_ent_clientes_his
          (cod_ente, cod_persona, nro_cuenta, fec_desde, observacion)
        values
          (nvl(:new.cod_ente,:old.cod_ente), v_cod_persona, :old.nro_cuenta, sysdate, 'Código de Ente anterior: '||:old.cod_ente|| ' - ' ||'Código de ente nuevo: '||:new.cod_ente);
      END IF;
   ELSIF deleting THEN
     --Borrar..
      DELETE
      FROM GE_CUENTAS
      WHERE nro_cuenta = :old.nro_cuenta;
   END IF;
 ELSIF updating AND user = fue_obt_des_refcodes('USU_CIERRE',user) THEN
   r_gcuen.nro_cuenta        := :new.nro_cuenta;
   v_nro_cuenta              := :new.nro_cuenta;
   r_gcuen.dig_verificador   := :new.dig_verificador;
   r_gcuen.denominacion      := :new.denominacion;
   r_gcuen.cod_modulo        := :new.cod_modulo;
   r_gcuen.cod_modalidad     := :new.cod_modalidad;
   r_gcuen.cod_oficina       := :new.cod_oficina;
   r_gcuen.estado            := :new.estado;
   r_gcuen.fec_cam_estado    := :new.fec_cam_estado;
   r_gcuen.sal_contable      := nvl(:new.sal_total,0)-nvl(:new.sal_retenido,0);
   r_gcuen.cod_moneda        := :new.cod_moneda;
   r_gcuen.fec_apertura      := :new.fec_apertura;
   r_gcuen.cod_tasa          := :new.cod_tasa;
   r_gcuen.fre_extracto      := :new.fre_extracto;
   r_gcuen.tas_personalizada := :new.tas_personalizada;
   r_gcuen.tra_prohibida     := :new.tra_prohibida;
   r_gcuen.ret_personalizada := :new.ret_personalizada;
   r_gcuen.cod_cau_cancelacion := :new.cod_cau_cancelacion;
   r_gcuen.cod_sub_modalidad := :new.cod_sub_modalidad;

   IF NVL(:NEW.MTO_DEB_PENDIENTES,0) <> NVL(:OLD.MTO_DEB_PENDIENTES,0) OR
      NVL(:NEW.MTO_CRE_PENDIENTES,0) <> NVL(:OLD.MTO_CRE_PENDIENTES,0) THEN
      NULL;
   ELSE
      IF :new.estado <> :old.estado AND :new.estado = 'N' THEN
         PAA_CTA.PRA_UPD_GE_CUENTAS(v_nro_cuenta, r_gcuen);
      END IF;
   END IF;
   /* Se anula la actualiza de la tabla NOC, porque genera abrazo mortal y bloqueos innecesarios
   --- Actualizaciones por casos ATM
   IF UPDATING THEN
      BEGIN
         select estado
           into v_est_modulo
           from ba_modulos
          where cod_modulo = 3;
         exception
            when no_data_found then
               raise_application_error(-20000,'Modulo 3 no registrado');
      END;
      --sólo si no es transferencia ctas combinadas automática
      if v_est_modulo in (1,3) and nvl(pae_cnf.G_PROGRAMA,'X') not in ('PRC_TRA_CTA_COM_INI') then
         if nvl(:new.sal_total,0)     <> nvl(:old.sal_total,0)
         or nvl(:new.sal_bloqueado,0) <> nvl(:old.sal_bloqueado,0)
         or nvl(:new.sal_retenido,0)  <> nvl(:old.sal_retenido,0) then
            update ah_cta_vistas_noc
               set sal_total = nvl(sal_total,0) + (nvl(:new.sal_total,0) - nvl(:old.sal_total,0)),
                   sal_bloqueado = nvl(sal_bloqueado,0) + (nvl(:new.sal_bloqueado,0) - nvl(:old.sal_bloqueado,0)),
                   sal_retenido = nvl(sal_retenido,0) + (nvl(:new.sal_retenido,0) - nvl(:old.sal_retenido,0))
             where nro_cuenta = :new.nro_cuenta;
         end if;
       end if;
    End if;
    */
  end if;
END;
/
