CREATE OR REPLACE TRIGGER IT.TB_CX_CTA_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CX_CTA_GARANTIAS
 FOR EACH ROW
declare
 v_cod_mon_cci   cx_cta_importaciones.cod_moneda%type;
 v_cod_modulo    cx_cta_importaciones.cod_modulo%type;
 v_cod_modalidad cx_cta_importaciones.cod_modalidad%type;
 v_cod_oficina   cx_cta_importaciones.cod_oficina%type;
 v_vto           cx_cta_importaciones.fec_vencimiento%type;
 v_per_cci       ba_personas.cod_persona%type;
 v_per_garantia  ba_personas.cod_persona%type;
 v_uti_tercero   pr_garantias.ind_uti_tercero%type;
 v_ins_gar_eliminadas VARCHAR2(1) DEFAULT 'N';
 rv_scgel        sb_cta_gar_eliminadas%ROWTYPE; 
 

BEGIN

   If (inserting or updating) then
     If :new.cod_garantia = 2 then
        -- Verifica si es codeudoria si la persona es juridica si puede o no ser codeudor.
        /*If pag_gen.FU_ES_PER_FISICA(:new.nro_garantia) = 'N' then
           if fue_pue_ser_codeudor(:new.nro_garantia) = 'N' then
              -- No puede ser codeudor...
              raise_application_error(-20000, 'La persona '||:new.nro_garantia||' No puede ser codeudor. Verifique.');
           End if;
        End if;*/
        null;
     Elsif :new.cod_garantia > 2 then
        -- Debe verificar que el cliente de la garantia sea el mismo que el de la carta...
        -- Obtiene el código de persona de la solicitud.
        Begin
           Select cod_persona
             into v_per_cci
             from ge_cta_clientes
            where nro_cuenta = :new.nro_cuenta
              and relacion = 'P';
           -- Obtiene el código de persona de la garantia y si puede ser usado por un tercero...
           Select cod_persona, nvl(ind_uti_tercero, 'N')
             into v_per_garantia, v_uti_tercero
             from pr_garantias
            where nro_garantia = :new.nro_garantia;
        exception
           when no_data_found then
              raise_application_error(-20000, 'Garantía '||:new.nro_garantia||' no existe');
        end;
        --- Verifica si corresponde o no...
			If v_per_garantia != v_per_cci and v_uti_tercero = 'N' then
			   -- No puede ser utilizado por un tercero...
			   raise_application_error(-20000, 'La garantía '||:new.nro_garantia||' No puede ser utilizada por un tercero. Verifique.');
			End if;
     End if;
   End if;

   if inserting then
      --buscar cci o fianza, sólo si es cash
      --if :new.cod_garantia = 5 then
      if fup_obt_nom_tab_anexa(:new.cod_garantia) = 'PR_GAR_CASH' then
        begin
          select cod_moneda, cod_modulo, cod_modalidad, cod_oficina, fec_vencimiento
            into v_cod_mon_cci, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_vto
            from cx_cta_importaciones
           where nro_cuenta = :new.nro_cuenta;
        exception
           when no_data_found then
             --buscar fianza
              begin
                select cod_moneda, cod_modulo, cod_modalidad, cod_oficina, fec_vencimiento
                  into v_cod_mon_cci, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_vto
                  from cx_fianzas
                 where nro_cuenta = :new.nro_cuenta;
              exception
                 when no_data_found then
                   raise_application_error(-20000,'Fianza inexistente '||:new.nro_cuenta);
                 when others then
                   raise_application_error(-20000,'Recup.Fianza '||sqlerrm);
              End;
           when others then
             if sqlcode <= -20000 then
                raise;
             else
                raise_application_error(-20000,'Recup.CCI. '||sqlerrm);
             end if;
        End;
      end if;
      --- Si el monto aplicado no es nulo y el mto computable es nulo
      --- actualizar el monto computable con el monto aplicado
      --- esto es debido a que la primera vez por desembolso es nulo
      if :new.mto_apl_computable is null then
         :new.mto_apl_computable := nvl(:new.mto_aplicado,0);
      end if;
      --Obtengo el codigo del cliente
      if :new.cod_persona is null then
         :new.cod_persona := fug_obt_cli_principal(:new.nro_cuenta);
      end if;
      --verificar si el saldo de la garantía cubre el monto
      /*if :new.cod_garantia > 2 and :new.nro_garantia is not null then
         -- si la garantía es cash se actualizan los bloqueos,saldos y estados de cuentas intervinientes.
         --La ejecución de este proceso se realiza en el trigger before porque en el after
         --da mutating al consultar la misma tabla.
         --if :new.cod_garantia = 5 then
          if fup_obt_nom_tab_anexa(:new.cod_garantia) = 'PR_GAR_CASH' then
           begin
           pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, :new.nro_cuenta, null, null, v_cod_modulo,
                      v_cod_modalidad, v_cod_oficina, v_cod_mon_cci, :new.mto_aplicado);

           exception
              when others then
                raise_application_error(-20222,'Cash '||sqlerrm);
           end;
         end if;
      end if;*/
   end if;
   
   if updating then
      if :old.nro_garantia <> :new.nro_garantia
         or :old.cod_garantia <> :new.cod_garantia
         or :old.mto_aplicado <> :new.mto_aplicado then
         v_ins_gar_eliminadas := 'S';
      end if;
   end if;
   
   if deleting then
      v_ins_gar_eliminadas := 'S';
   end if;

   if nvl(v_ins_gar_eliminadas, 'N') = 'S' and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
      rv_scgel.cod_persona := :old.cod_persona;
      rv_scgel.fecha := to_date(to_char(sysdate,'dd/mm/yyyy')||to_char(sysdate,'hh24:mi:ss') , 'dd/mm/yyyy hh24:mi:ss');
      rv_scgel.hora := to_char(sysdate,'HH24:MI:SS');
      rv_scgel.nro_garantia := nvl(:old.nro_garantia, 0);
      rv_scgel.nro_cuenta := :old.nro_cuenta;
      rv_scgel.cod_garantia := :old.cod_garantia;
      rv_scgel.mto_apl_computable := :old.mto_aplicado;
      pas_cri.pr_ins_cta_gar_eliminadas(rv_scgel);
   end if;        
END;
/

