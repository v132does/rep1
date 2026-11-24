CREATE OR REPLACE PROCEDURE IT.PRG_VER_MOV_NOC_INI IS
   v_lugar      VARCHAR2(2000);
   v_sal_total cc_cta_corrientes.sal_total%type;
   v_sal_retenido cc_cta_corrientes.sal_total%type;
   v_cuentas varchar2(200);
   v_can_cta_error  number;
   v_parametro ge_par_dinamicos.val_parametro%type:=nvl(fug_obt_pardinamico('NRO_CTA_EXC_VER_INI'), '0');
   v_error varchar2(4000);
   
   cursor c_cta_corrientes is
    select a.*
      from cc_cta_corrientes a
    WHERE instr(v_parametro, a.nro_cuenta) = 0
      and EXISTS (SELECT 1
             FROM cc_cta_corrientes_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));

   cursor c_cta_ahorros is
    select a.*
      from ah_cta_vistas a
    WHERE instr(v_parametro, a.nro_cuenta) = 0
      and EXISTS (SELECT 1
             FROM ah_cta_vistas_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));
BEGIN
   v_lugar      := 'Verifica Ctas.Ctes.';
   v_cuentas := null;
   v_can_cta_error := 0;
   
   for cte in c_cta_corrientes loop
        v_sal_total := 0;
        v_sal_retenido := 0;       
        
        SELECT (nvl(cte.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)),
                (nvl(cte.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0))
          into v_sal_total, v_sal_retenido
          FROM cc_cta_corrientes_noc b
         WHERE b.nro_cuenta = cte.nro_cuenta;

       ----Control igual que constraint--
       if nvl(v_sal_retenido,0) < 0 then
          v_can_cta_error := nvl(v_can_cta_error,0) +1;
          if length(nvl(v_cuentas,'0')) <= 180 then
             if v_cuentas is null then
                v_cuentas := cte.nro_cuenta;
             else
                v_cuentas := v_cuentas||','||cte.nro_cuenta;
             end if;
           end if;
       end if;
   end loop; 

   v_lugar := 'Verifica Ahorro Vista';
   for cta in c_cta_ahorros loop
        v_sal_total := 0;
        v_sal_retenido := 0;       
        
        SELECT (nvl(cta.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)),
                (nvl(cta.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0))
          into v_sal_total, v_sal_retenido
          FROM ah_cta_vistas_noc b
         WHERE b.nro_cuenta = cta.nro_cuenta;

       ----Control igual que constraint--
       if nvl(v_sal_total,0) < 0 then
          v_can_cta_error := nvl(v_can_cta_error,0) +1;
          if length(nvl(v_cuentas,'0')) <= 180 then
             if v_cuentas is null then
               v_cuentas := cta.nro_cuenta;
             else
               v_cuentas:= v_cuentas||','||cta.nro_cuenta;
             end if;
           end if;
       end if;

       if nvl(v_sal_retenido,0) < 0 then
          v_can_cta_error := nvl(v_can_cta_error,0) +1;
          if length(nvl(v_cuentas,'0')) <= 180 then
             if v_cuentas is null then
               v_cuentas := cta.nro_cuenta;
             else
               v_cuentas:= v_cuentas||','||cta.nro_cuenta;
             end if;
           end if;
       end if;
   end loop;
   if v_cuentas is not null then
      --raise_application_error(-20001, v_lugar ||' - '|| 'Saldo Negativo (Cant Ctas. '||v_can_cta_error||')'||'-Cta#: ' ||v_cuentas);
      begin
        update ge_par_dinamicos
           set val_parametro = v_cuentas
         where parametro = 'NRO_CTA_EXC_VER_INI';
        if sql%notfound then
          insert into ge_par_dinamicos
            (parametro, val_parametro)
          values
            ('NRO_CTA_EXC_VER_INI', v_cuentas);
        end if;
      exception
        when others then
          v_error := substr(sqlerrm,1,4000);
          prg_ins_log_errores('PRG_VER_MOV_NOC_INI',v_error,'NRO_CUENTA',v_cuentas);
      end;
      
   end if;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, v_lugar ||chr(10)||chr(13)||'Se debe excluir la cuenta en el parametro NRO_CTA_EXC_VER_INI y volver a ejecutar este proceso'|| ' ' ||chr(10)||chr(13)|| SQLERRM);
END;
/
