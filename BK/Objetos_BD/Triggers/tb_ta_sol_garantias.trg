CREATE OR REPLACE TRIGGER IT.TB_TA_SOL_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON TA_SOL_GARANTIAS
 FOR EACH ROW
declare
 v_estado ta_solicitudes.cod_estado%type := null;
 v_nro_solicitud ta_solicitudes.nro_solicitud%type;
 v_cod_mon_sol   ta_solicitudes.cod_moneda%type;
 v_cod_modulo    ta_solicitudes.cod_modulo%type;
 v_cod_modalidad ta_solicitudes.cod_modalidad%type;
 v_cod_oficina   ta_solicitudes.cod_oficina%type;
 v_nom_tab_anexa pr_gar_tipos.nom_tab_anexa%type;

BEGIN
   if inserting or updating then
      v_nro_solicitud := :new.nro_solicitud;
   else
      v_nro_solicitud := :old.nro_solicitud;
   end if;
   v_nom_tab_anexa := fup_obt_nom_tab_anexa(:new.cod_garantia);
   --if :new.cod_garantia = 5 then --sólo para cash
   if v_nom_tab_anexa = 'PR_GAR_CASH' then
     begin
       select cod_estado, cod_moneda, cod_modulo, cod_modalidad, cod_oficina
         into v_estado,v_cod_mon_sol, v_cod_modulo, v_cod_modalidad, v_cod_oficina
         from ta_solicitudes x
        where x.nro_solicitud = v_nro_solicitud;
     exception
        when others then
           raise_application_error(-20000,
             'En obtener estado de Solicitud.'||sqlerrm);
     end;
  
     --sólo por insert verificar el saldo de la garantía
     /*if inserting then
          --si la garantía es cash se actualizan los bloqueos,saldos y estados de cuentas intervinientes.
          --La ejecución de este proceso se realiza en el trigger before porque en el after
          --da mutating al consultar la misma tabla. 
          ------------------------------------------
          --el pmdesdoc graba nro_solicitud negativo, entonces q afecte al cda recién en la actualización
          --porque de lo contrario asocia el bloqueo a la solicitud negativa, entonces se hace en la aplicación
          --ya q x actualización da mutating
          if nvl(:new.nro_solicitud,0) >0 then
            --if :new.cod_garantia = 5 then
            if v_nom_tab_anexa = 'PR_GAR_CASH' then
               pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, null, :new.nro_solicitud, null, v_cod_modulo,
                          v_cod_modalidad, v_cod_oficina, v_cod_mon_sol,:new.mto_aplicado);
            end if;
          end if;
     end if;*/
   end if;
END;
/

