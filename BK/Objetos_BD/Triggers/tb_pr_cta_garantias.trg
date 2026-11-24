CREATE OR REPLACE TRIGGER IT.TB_PR_CTA_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_CTA_GARANTIAS
 FOR EACH ROW
declare
 v_cod_mon_pres  pr_cta_prestamos.cod_moneda%type;
 v_cod_mon_gar   pr_cta_prestamos.cod_moneda%type;
 v_mto_utilizado pr_solicitudes.monto%type;
 v_gar_saldo     pr_garantias.mto_aplicado%type;
 v_cod_modulo    pr_cta_prestamos.cod_modulo%type;
 v_cod_modalidad pr_cta_prestamos.cod_modalidad%type;
 v_cod_oficina   pr_cta_prestamos.cod_oficina%type;
 v_vto           pr_cta_prestamos.fec_vencimiento%type;
 v_nro_solicitud pr_solicitudes.nro_solicitud%type;
 v_per_prestamo  ba_personas.cod_persona%type;
 v_per_garantia  ba_personas.cod_persona%type;
 v_uti_tercero   pr_garantias.ind_uti_tercero%type;
 v_ins_gar_eliminadas varchar2(1) default 'N';
 rv_scgel        sb_cta_gar_eliminadas%rowtype;

/* Verificar si la garantía ya se cargó a la solicitud. */
FUNCTION LF_VER_GAR_SOLICITUD
 (P_NRO_GARANTIA IN PR_GAR_CASH.NRO_GARANTIA%TYPE,
  P_COD_GARANTIA IN PR_GARANTIAS.COD_GARANTIA%TYPE,
 P_NRO_SOLICITUD IN OUT PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
RETURN BOOLEAN IS
BEGIN
   SELECT NRO_SOLICITUD
   INTO P_NRO_SOLICITUD
   FROM PR_SOL_GARANTIAS
   WHERE NRO_GARANTIA = P_NRO_GARANTIA
   AND COD_GARANTIA =P_COD_GARANTIA;
   RETURN TRUE;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
      RETURN TRUE;
   WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
   WHEN OTHERS THEN
        RETURN FALSE;
END;

BEGIN

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
     Elsif :new.cod_garantia NOT IN (1,2,42) then
        -- Debe verificar que el cliente de la garantia sea el mismo que el de la solicitud...
        -- Obtiene el código de persona de la solicitud.
        begin
           Select cod_persona
             into v_per_prestamo
             from ge_cta_clientes
            where nro_cuenta = :new.nro_cuenta
              and relacion = 'P'
              and rownum = 1;
       exception
           when no_data_found then
              raise_application_error(-20000, 'Cuenta '||:new.nro_cuenta||' no existe');
        end;
        Begin
           -- Obtiene el código de persona de la garantia y si puede ser usado por un tercero...
           --sólo si tiene nro_garantia
           if :new.nro_garantia is not null then
             Select cod_persona, nvl(ind_uti_tercero, 'N')
               into v_per_garantia, v_uti_tercero
               from pr_garantias
              where nro_garantia = :new.nro_garantia;
           end if;
        exception
           when no_data_found then
              raise_application_error(-20001, 'Garantía '||:new.nro_garantia||' no existe');
        end;
        --- Verifica si corresponde o no...
        If v_per_garantia != v_per_prestamo and v_uti_tercero = 'N'
        and nvl(pae_cnf.g_programa, 'X') <> 'GPPROFIN' then
           -- No puede ser utilizado por un tercero...
           raise_application_error(-20000, 'La garantia '||:new.nro_garantia||' No puede ser utilizada por un tercero. Verifique.');
        End if;
     End if;
   End if;

   if inserting then
      begin
        select cod_moneda, cod_modulo, cod_modalidad, cod_oficina, fec_vencimiento
          into v_cod_mon_pres, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_vto
          from pr_cta_prestamos
         where nro_cuenta = :new.nro_cuenta;
      exception
         when no_data_found then
           raise_application_error(-20000,'Cta.Prést. inexistente '||:new.nro_cuenta);
         when others then
           raise_application_error(-20000,'Recup.Prést. '||sqlerrm);
      End;
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
      if :new.cod_garantia NOT IN (1,2,42) and :new.nro_garantia is not null then
        if fug_obt_tip_implementacion =3 then --atlas
            --sólo si no existe pr_solicitudes, o sino ya verificó al cargar la solicitud
            if not lf_ver_gar_solicitud(:new.nro_garantia,:new.cod_garantia,v_nro_solicitud) then
               --obtiene el monto de operaciones aplicados de la garantía
               v_mto_utilizado:= pap_gar.FU_OBT_MTO_OPE_GARANTIA(:new.nro_garantia);
               v_gar_saldo:= pap_gar.FU_OBT_VAL_COMPUTABLE(:new.nro_garantia) - v_mto_utilizado;
               --obtiene moneda de la garantía
               v_cod_mon_gar := pap_gar.FU_OBT_MON_GARANTIA(:new.nro_garantia);
               --verificar monedas
               if v_cod_mon_gar <> v_cod_mon_pres then
                  v_gar_saldo := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_gar,v_cod_mon_pres,v_gar_saldo);
               end if;
               if :new.mto_aplicado > v_gar_saldo then
                  --mostrar saldos en moneda solicitud
                  raise_application_error(-20002,'Saldo de garantía: '||v_gar_saldo||' '||v_cod_mon_pres||'. no cubre el Monto Aplicado: '||:new.mto_aplicado||' '||v_cod_mon_pres);
               end if;
            end if;
         end if;
         /* si la garantía es cash se actualizan los bloqueos,saldos y estados de cuentas intervinientes.
         La ejecución de este proceso se realiza en el trigger before porque en el after
         da mutating al consultar la misma tabla. */
         --if :new.cod_garantia = 5 then
         /*if fup_obt_nom_tab_anexa(:new.cod_garantia) = 'PR_GAR_CASH' then
           pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, :new.nro_cuenta, null, v_vto, v_cod_modulo,
                      v_cod_modalidad, v_cod_oficina, v_cod_mon_pres, :new.mto_aplicado);

         end if;*/
      end if;
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

   if nvl(v_ins_gar_eliminadas, 'N') = 'S' and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN'  then
      rv_scgel.fecha := to_date(to_char(sysdate,'DDMMYYYY')||pag_gen.fu_obt_sig_segundo(to_char(sysdate, 'HH24:MI:SS')),'DDMMYYYY HH24:MI:SS');
      rv_scgel.hora  := pag_gen.fu_obt_sig_segundo(to_char(sysdate, 'HH24:MI:SS'));
      rv_scgel.cod_persona := :old.cod_persona;
      rv_scgel.nro_garantia := nvl(:old.nro_garantia, 0);
      rv_scgel.nro_cuenta := :old.nro_cuenta;
      rv_scgel.cod_garantia := :old.cod_garantia;
      rv_scgel.mto_apl_computable := :old.mto_aplicado;
      pas_cri.pr_ins_cta_gar_eliminadas(rv_scgel); -- Se pasa el control de la excepcion dentro del procedimiento -- CN DYDMR-1020 --
   end if;
END;
/

