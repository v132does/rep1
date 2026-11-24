CREATE OR REPLACE TRIGGER IT.TA_CC_CTA_CORRIENTES
 BEFORE DELETE OR INSERT OR UPDATE 
 ON CC_CTA_CORRIENTES
 FOR EACH ROW

DECLARE
   r_gcuen      ge_cuentas%ROWTYPE; -- Registro de la tabla GE_CUENTAS
   v_nro_cuenta ge_cuentas.nro_cuenta%TYPE := :new.nro_cuenta;
   --v_est_modulo ba_modulos.estado%TYPE;
   v_cod_persona ba_personas.cod_persona%type;
   v_tip_extracto ge_clientes.tip_extracto%type;
   v_tip_persona  ba_personas.tipo%type;
   v_existe       varchar2(1);
BEGIN
   IF inserting OR updating THEN
      r_gcuen.nro_cuenta          := :new.nro_cuenta;
      v_nro_cuenta                := :new.nro_cuenta;
      r_gcuen.dig_verificador     := :new.dig_verificador;
      r_gcuen.denominacion        := :new.denominacion;
      r_gcuen.cod_modulo          := :new.cod_modulo;
      r_gcuen.cod_modalidad       := :new.cod_modalidad;
      r_gcuen.cod_oficina         := :new.cod_oficina;
      r_gcuen.estado              := :new.estado;
      r_gcuen.fec_cam_estado      := :new.fec_cam_estado;
      r_gcuen.sal_contable        := nvl(:new.sal_total, 0) - nvl(:new.sal_retenido, 0);
      r_gcuen.cod_moneda          := :new.cod_moneda;
      r_gcuen.fec_apertura        := :new.fec_apertura;
      r_gcuen.fre_extracto        := :new.fre_extracto;
      r_gcuen.tas_personalizada   := :new.tas_personalizada;
      r_gcuen.tra_prohibida       := :new.tra_prohibida;
      r_gcuen.ret_personalizada   := :new.ret_personalizada;
      r_gcuen.en_juicio           := :new.en_juicio;
      r_gcuen.fec_juicio          := :new.fec_juicio;
      r_gcuen.cod_ent_juicio      := :new.cod_ent_juicio;
      --r_gcuen.dia_atraso          := :new.dia_atraso;
      --r_gcuen.pro_atraso          := :new.pro_atraso;
      --r_gcuen.max_atraso          := :new.max_atraso;
      --r_gcuen.mto_mora            := :new.mto_mora;
      r_gcuen.cod_cau_cancelacion := :new.cod_cau_cancelacion;
      r_gcuen.cod_sub_modalidad   := :new.cod_sub_modalidad;
   END IF;
   IF inserting THEN
      --- Insertar tabla de Cuentas
      paa_cta.pra_ins_ge_cuentas(r_gcuen);
   ELSIF updating THEN
      IF :old.nro_cuenta <> :new.nro_cuenta THEN
         v_nro_cuenta := :old.nro_cuenta;
      END IF;
      IF :new.reg_firma <> nvl(:old.reg_firma, 'x') OR
         nvl(:new.cta_combinada, 'X') <> nvl(:old.cta_combinada, 'X') OR
         nvl(:new.denominacion, 'X') <> nvl(:old.denominacion, 'X') THEN
         r_gcuen.est_verificacion := 'N'; -- sin verificar
      END IF;
      IF nvl(:new.mto_deb_pendientes, 0) <> nvl(:old.mto_deb_pendientes, 0) OR
         nvl(:new.mto_cre_pendientes, 0) <> nvl(:old.mto_cre_pendientes, 0) THEN
         NULL; -- no se debe actualizar para no bloquear el atm, porque es cierre. 
      ELSE
         paa_cta.pra_upd_ge_cuentas(v_nro_cuenta, r_gcuen);
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
      IF nvl(:new.cod_ente,-1) <> nvl(:old.cod_ente,-1) THEN
         update ge_cta_dat_adicionales
            set val_parametro = to_char(pag_cal.FU_OBT_FEC_ACTUAL(4),'dd/mm/yyyy')
          where parametro = 'SOB_FEC_INI_LINEA'
            and nro_cuenta = :new.nro_cuenta;
       IF SQL%NOTFOUND THEN
              insert into ge_cta_dat_adicionales(nro_cuenta,parametro,val_parametro)
                            values(:new.nro_cuenta,'SOB_FEC_INI_LINEA',to_char(pag_cal.FU_OBT_FEC_ACTUAL(4),'dd/mm/yyyy'));
       END IF;
       --PCCREPAN-3 Mejoras Pago de Nómina Fase 1 - Proceso de Altas
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
      DELETE FROM ge_cuentas WHERE nro_cuenta = :old.nro_cuenta;
   END IF;
   /* Se elimina porque genera abrazo mortal y bloqueos innecesarios
   --- Actualizaciones por casos ATM
   IF updating THEN
      BEGIN
         SELECT estado INTO v_est_modulo FROM ba_modulos WHERE cod_modulo = 4;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Modulo 4 no registrado');
      END;
      --sólo si no es transferencia ctas combinadas automática
      IF v_est_modulo IN (1, 3) AND nvl(pae_cnf.g_programa, 'X') NOT IN ('PRC_TRA_CTA_COM_INI') THEN
         IF nvl(:new.sal_total, 0) <> nvl(:old.sal_total, 0) OR
            nvl(:new.sal_bloqueado, 0) <> nvl(:old.sal_bloqueado, 0) OR
            nvl(:new.sal_retenido, 0) <> nvl(:old.sal_retenido, 0) THEN
            UPDATE cc_cta_corrientes_noc
               SET sal_total     = nvl(sal_total, 0) +
                                   (nvl(:new.sal_total, 0) - nvl(:old.sal_total, 0)),
                   sal_bloqueado = nvl(sal_bloqueado, 0) +
                                   (nvl(:new.sal_bloqueado, 0) - nvl(:old.sal_bloqueado, 0)),
                   sal_retenido  = nvl(sal_retenido, 0) +
                                   (nvl(:new.sal_retenido, 0) - nvl(:old.sal_retenido, 0))
             WHERE nro_cuenta = :new.nro_cuenta;
         END IF;
      END IF;
   END IF;
   */
   ---PCCDEEVO-368 - Ajuste en verificación de chequeras en casa. 22/05/2017--- 
  if updating then
   if :new.estado <> :old.estado and :new.estado in ('C', 'P') then
    begin
     select 'S' into v_existe
        from cc_sol_chequeras
       where nro_cuenta = :old.nro_cuenta
         and estado = 'S';
    exception
         when no_data_found then
            v_existe := 'N';
         when too_many_rows then
            v_existe := 'S';
         when others then
            v_existe := 'N';
    end;
      if v_existe = 'S' then
        update cc_sol_chequeras 
         set estado = 'R',
             observacion = 'Rechazado por Cta. Cancelada'  
         where nro_cuenta = :old.nro_cuenta
         and estado = 'S'; 
      end if;     
   end if;
 end if;
END;
/

