CREATE OR REPLACE TRIGGER IT.TB_PR_SOL_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_SOL_GARANTIAS
 FOR EACH ROW
declare
 v_estado pr_solicitudes.estado%type := null;
 v_nro_solicitud pr_solicitudes.nro_solicitud%type;
 v_cod_mon_sol   pr_solicitudes.cod_moneda%type;
 v_cod_mon_gar   pr_solicitudes.cod_moneda%type;
 v_mto_utilizado pr_solicitudes.monto%type;
 v_gar_saldo     pr_garantias.mto_aplicado%type;
 v_cod_modulo    pr_solicitudes.cod_modulo%type;
 v_cod_modalidad pr_solicitudes.cod_modalidad%type;
 v_cod_oficina   pr_solicitudes.cod_oficina%type;
 v_vto           pr_solicitudes.fec_vencimiento%type;
 v_per_solicitud ba_personas.cod_persona%type;
 v_per_garantia  ba_personas.cod_persona%type;
 v_uti_tercero   pr_garantias.ind_uti_tercero%type;
 v_existe        number := 0;

BEGIN
   if inserting or updating then
      v_nro_solicitud := :new.nro_solicitud;
   else
      v_nro_solicitud := :old.nro_solicitud;
   end if;
   begin
     select estado, cod_moneda, cod_modulo, cod_modalidad, cod_oficina, fec_vencimiento
       into v_estado,v_cod_mon_sol, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_vto
       from pr_solicitudes x
      where x.nro_solicitud = v_nro_solicitud;
   exception
      when others then
         raise_application_error(-20000,
           'Error. En obtener estado de Propuesta.');
   end;
   if updating then
      if v_estado not in ('C','S') then
        if :new.cod_garantia <> :old.cod_garantia then
           raise_application_error(-20000,
           'El tipo de garantía no puede modificarse');
        end if;
      end if;
   end if;
   ---DM 07/02/2010 si es cheq.dev. de implementacion 9 no hace la validación ---
   if v_estado <> 'L' and v_cod_modalidad <> 660 and fug_obt_tip_implementacion <> 9  then 
    if (inserting or deleting) and ((v_estado not in ('C','S','R','P') and v_cod_modalidad != 60) or
	                                (v_estado not in ('C','S','L','R','P') and v_cod_modalidad = 60)) then
       raise_application_error(-20000,
       'No pueden actualizarse garantias de solicitudes procesadas');
    end if;
   end if;
   
   If (inserting or updating) then
     If :new.cod_garantia = 2 then
       -- no se controla más VC 09-08-2010
       -- Verifica si es codeudoria si la persona es juridica si puede o no ser codeudor.
        /*If pag_gen.FU_ES_PER_FISICA(:new.nro_garantia) = 'N' then
           if fue_pue_ser_codeudor(:new.nro_garantia) = 'N' then
              -- No puede ser codeudor...
              raise_application_error(-20000, 'La persona '||:new.nro_garantia||' No puede ser codeudor. Verifique.');
           End if;
        End if;*/
       null; 
     Elsif :new.cod_garantia > 2 then
        -- Debe verificar que el cliente de la garantia sea el mismo que el de la solicitud...
        -- Obtiene el código de persona de la solicitud.
        Select cod_persona
          into v_per_solicitud
          from pr_solicitudes
         where nro_solicitud = :new.nro_solicitud;
        -- Obtiene el código de persona de la garantia y si puede ser usado por un tercero...
        Select cod_persona, nvl(ind_uti_tercero, 'N')
          into v_per_garantia, v_uti_tercero
          from pr_garantias
         where nro_garantia = :new.nro_garantia;
        -- Verifico tabla de terceros
        Select count(1)
          into v_existe
          from pr_gar_terceros
         where nro_garantia = :new.nro_garantia
           and cod_persona = v_per_solicitud;
        --- Verifica si corresponde o no...
        If v_per_garantia != v_per_solicitud and v_uti_tercero = 'N' then
              -- No puede ser utilizado por un tercero...
              raise_application_error(-20000, 'La garantia '||:new.nro_garantia||' No puede ser utilizada por un tercero. Verifique.');
        Elsif v_uti_tercero = 'S' and v_existe = 0 then
              -- No puede ser utilizado por la persona...
              raise_application_error(-20000, 'La garantia '||:new.nro_garantia||' No puede ser utilizada por la persona. Verifique.');
        End if;
     End if;
   End if;

   --sólo por insert verificar el saldo de la garantía
   if inserting then
      if :new.cod_garantia > 2 and :new.nro_garantia is not null then
        if fug_obt_tip_implementacion =3 then --atlas
           --obtiene el monto de operaciones aplicados de la garantía
           v_mto_utilizado:= pap_gar.FU_OBT_MTO_OPE_GARANTIA(:new.nro_garantia);
           v_gar_saldo:= pap_gar.FU_OBT_VAL_COMPUTABLE(:new.nro_garantia) - v_mto_utilizado;
           --obtiene moneda de la garantía
           v_cod_mon_gar := pap_gar.FU_OBT_MON_GARANTIA(:new.nro_garantia);
           --verificar monedas
           if v_cod_mon_gar <> v_cod_mon_sol then
              v_gar_saldo := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_gar,v_cod_mon_sol,v_gar_saldo);
           end if;
           if :new.mto_aplicado > v_gar_saldo then
              --mostrar saldos en moneda solicitud
              raise_application_error(-20002,'Saldo de garantía: '||v_gar_saldo||' '||v_cod_mon_sol||'. no cubre el Monto Aplicado: '||:new.mto_aplicado||' '||v_cod_mon_sol);
           end if;
        end if;
        /* si la garantía es cash se actualizan los bloqueos,saldos y estados de cuentas intervinientes.
        La ejecución de este proceso se realiza en el trigger before porque en el after
        da mutating al consultar la misma tabla. */
        --el pmdesdoc graba nro_solicitud negativo, entonces q afecte al cda recién en la actualización
        --porque de lo contrario asocia el bloqueo a la solicitud negativa, entonces se hace en la aplicación
        --ya q x actualización da mutating
        /*if nvl(:new.nro_solicitud,0) >0 then
          --if :new.cod_garantia = 5 then
          if fup_obt_nom_tab_anexa(:new.cod_garantia) = 'PR_GAR_CASH' then
             pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, null, :new.nro_solicitud, v_vto, v_cod_modulo,
                        v_cod_modalidad, v_cod_oficina, v_cod_mon_sol,:new.mto_aplicado);
          end if;
        end if;*/
      end if;
   end if;
END;
/

