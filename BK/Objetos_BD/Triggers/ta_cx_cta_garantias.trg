CREATE OR REPLACE TRIGGER IT.TA_CX_CTA_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CX_CTA_GARANTIAS
 FOR EACH ROW

DECLARE

  v_nro_linea      pr_lineas.nro_linea%type;
  v_cod_mon_linea  pr_lineas.cod_moneda%type;
  v_cod_mod_cci    cx_cta_importaciones.cod_modalidad%type;
  v_per_cci        ge_cta_clientes.cod_persona%type;
  v_cod_mon_cci    cx_cta_importaciones.cod_moneda%type;
  v_cod_mon_gar    pr_garantias.cod_moneda%type;
  v_cod_ofi_cci    cx_cta_importaciones.cod_oficina%type;
  v_dig_verificador ge_cuentas.dig_verificador%type;
  v_mto_a_aplicar  pr_lineas.mto_aplicado%type;
  v_mto_aplicado   pr_lineas.mto_aplicado%type;
  v_cot_mon_ori    ge_cotizaciones.val_conversion%type;
  v_cot_mon_des    ge_cotizaciones.val_conversion%type;
  v_existe varchar2(1):='N';

  v_nro_cuenta     cx_cta_importaciones.nro_cuenta%type;

BEGIN
   if inserting or updating then
      v_nro_cuenta := :new.nro_cuenta;
   else
      v_nro_cuenta := :old.nro_cuenta;
   end if;
  --buscar cci o fianza
   begin
      select nro_linea, cod_moneda, cod_modalidad
        into v_nro_linea, v_cod_mon_cci, v_cod_mod_cci
        from cx_cta_importaciones
       where nro_cuenta = v_nro_cuenta;
   exception
      when no_data_found then
         --buscar fianza
         begin
          select nro_linea, cod_moneda, cod_modalidad
            into v_nro_linea, v_cod_mon_cci, v_cod_mod_cci
            from cx_fianzas
           where nro_cuenta = v_nro_cuenta;
         exception
           when no_data_found then
             v_nro_linea := null;
         end;
   End;

   --- POR ELIMINACION O MODIFICACION DEL MONTO APLICADO
   If deleting OR updating  then
     IF nvl(:new.mto_apl_computable,0) <> nvl(:old.mto_apl_computable,0) then
       begin
          If :old.cod_garantia > 2 and :old.nro_garantia is not null then
            -- Actualizar monto aplicado de garantia
            pap_gar.pr_act_gar_aplicado(:old.nro_garantia, v_cod_mon_cci, (nvl(:old.mto_apl_computable,0)*-1));
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_cci, nvl(:new.mto_apl_computable,0));
          End if;
        exception
          when others then
            If sqlcode <= -20000 then
              raise;
            else
              raise_application_error(-20001,'Al Actualizar Garantía'||sqlerrm);
            End if;
        end;
      end if;
   End if;

  --- POR INSERT
  if inserting then
    --actualizar la garantia con el nuevo monto aplicado computable
    --sólo si no existe pr_solicitudes, o sino ya se actualizó por el insert de la misma
    If :new.cod_garantia > 2 then    
       if nvl(:new.mto_apl_computable,0) <> 0 then
          pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_cci, nvl(:new.mto_apl_computable,0));
       end if;
    end if;
  elsif updating and nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0) then
    begin
      --Actualizar el mto aplicado de garantias por limite
      If v_nro_linea is not null then
        If :new.cod_garantia > 2 then
          -- Recuperar moneda de la linea y de la garantia
          v_cod_mon_linea  := pap_gar.fu_obt_mon_linea(v_nro_linea);
          v_cod_mon_gar    := pap_gar.fu_obt_mon_garantia(:new.nro_garantia);
          -- Convertir el monto a moneda de la linea en la cotizacion actual
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_cci,v_cod_mon_linea,
                                     nvl(:new.mto_aplicado,0), v_mto_a_aplicar,
                                     v_cot_mon_ori, v_cot_mon_des);
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_cci,v_cod_mon_linea,
                                     nvl(:old.mto_aplicado,0), v_mto_aplicado,
                                     v_cot_mon_ori, v_cot_mon_des);
        else
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_cci,v_cod_mon_linea,
                                     nvl(:new.mto_aplicado,0), v_mto_a_aplicar,
                                     v_cot_mon_ori, v_cot_mon_des);
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_cci,v_cod_mon_linea,
                                     nvl(:old.mto_aplicado,0), v_mto_aplicado,
                                     v_cot_mon_ori, v_cot_mon_des);
        End if;
        pap_gar.pr_act_tip_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_aplicado,0));
        --Actualizar el mto aplicado de garantias por Modalidad
        pap_gar.pr_act_mad_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_aplicado,0),8,v_cod_mod_cci);
      End if;
    exception
      when others then
        If sqlcode <= -20000 then
          raise;
        else
          raise_application_error(-20000,'Al actualizar garantias '||sqlerrm);
        End if;
    end;
  end if;
  --por inserción 
  if inserting or updating then
     --si es codeudoría
     If :new.cod_garantia = 2 then
        --recuperar datos de la cci       
        begin
          select cod_moneda, a.cod_modalidad, a.cod_oficina, cod_persona, dig_verificador
            into v_cod_mon_cci, v_cod_mod_cci, v_cod_ofi_cci, v_per_cci, v_dig_verificador
            from ge_Cta_clientes b, cx_cta_importaciones a
           where b.nro_cuenta = a.nro_cuenta
             and relacion ='P'
             and a.nro_cuenta = :new.nro_cuenta;
        exception
           when no_data_found then
              --recuperar datos de la fianza
              begin
                select cod_moneda, a.cod_modalidad, a.cod_oficina, cod_per_solicitante, dig_verificador
                  into v_cod_mon_cci, v_cod_mod_cci, v_cod_ofi_cci, v_per_cci, v_dig_verificador
                  from cx_fianzas a
                 where a.nro_cuenta = :new.nro_cuenta;
              exception
                 when no_data_found then
                   raise_application_error(-20000,'Fianza inexistente '||:new.nro_cuenta);
                 when others then
                   raise_application_error(-20000,'Recup.Fianza '||sqlerrm);
              End;
           when others then
              if sqlcode < -20000 then
                 raise;
              else
                 raise_application_error(-20000,'Recup.CCI '||sqlerrm);
              end if;
        End;
        --si inserta o si es actualizacion y solo si cambió la persona
        if inserting or :new.nro_garantia <> nvl(:old.nro_garantia,-1) then
          --- Verificar si existe en Ge_clientes, sino insertar
          begin
            v_existe := 'N';
            select 'S' into v_existe
            from ge_clientes
            where cod_persona = :new.nro_garantia;
            exception
               when no_data_found then
           --- Insertar ge_clientes
           insert into ge_clientes
              (cod_persona,cod_oficina, cod_usu_oficial,
               cod_sec_contable,cod_tip_deudor, residente,
               cod_departamento)
           --- Agregar con los datos basicos del cliente principal de la cuenta
           select :new.nro_garantia, cl.cod_oficina, cl.cod_usu_oficial,
           cl.cod_sec_contable, cl.cod_tip_deudor, cl.residente, cl.cod_departamento
             from ge_clientes cl
            where cl.cod_persona = v_per_cci;
          end;
          --- Insertar Relación Cliente Cuenta
          insert into ge_cta_clientes
            (cod_persona, nro_cuenta, dig_verificador,
             cod_oficina, cod_modulo, cod_modalidad, relacion)
          values(:new.nro_garantia, v_nro_cuenta, v_dig_verificador,
             v_cod_ofi_cci, 8, v_cod_mod_cci, 'C');
        end if;
     end if;
     --si fue modificación eliminar el anterior
     if :old.cod_garantia = 2 then
        if :new.nro_garantia <> :old.nro_garantia then
           --- eliminar Relación Cliente Cuenta
           delete ge_cta_clientes
            where nro_cuenta = v_nro_cuenta
              and cod_persona = :old.nro_garantia;
        end if;
     end if;
  end if;
  if deleting then --por eliminación
     If :old.cod_garantia = 2 then
       --- eliminar Relación Cliente Cuenta
       delete ge_cta_clientes
        where nro_cuenta = v_nro_cuenta
          and cod_persona = :old.nro_garantia;
     end if;
  end if;
END;
/

