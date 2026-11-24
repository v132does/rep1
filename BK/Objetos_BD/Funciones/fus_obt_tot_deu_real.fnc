CREATE OR REPLACE FUNCTION IT.fus_obt_tot_deu_real(p_cod_persona   in ba_personas.cod_persona%type,
                                                p_cod_moneda    in ge_cuentas.cod_moneda%type)
   RETURN NUMBER IS
  v_mon_local    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_tot_deuda    number := 0;
  v_sal_cuenta   number := 0;
  v_cotizacion   ge_cotizaciones.val_conversion%type;
  
  cursor cuentas is
    select a.nro_cuenta, b.cod_modulo, b.cod_modalidad, b.cod_moneda, b.sal_contable saldo
      from ge_cta_clientes a, ge_cuentas b, ge_est_cuentas c
     where a.cod_persona = p_cod_persona
       and a.relacion = 'P'
       and a.nro_cuenta = b.nro_cuenta
       and (b.cod_modulo in (5,6,8) or (b.cod_modulo = 4 and b.sal_contable < 0))
       and b.cod_modulo = c.cod_modulo 
       and b.cod_modalidad = c.cod_modalidad
       and b.estado = c.estado 
       and c.activo = 'S';
begin
  for x in cuentas loop
    if x.cod_moneda = p_cod_moneda then
        if x.cod_modulo= 4 and x.saldo<0 then
          v_sal_cuenta := (x.saldo*-1);
        else
          v_sal_cuenta := x.saldo;
        end if;
    else
      if v_mon_local = x.cod_moneda then
        v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, pae_cnf.fu_obt_fec_actual(1));
        if x.cod_modulo= 4 and x.saldo < 0 then
          v_sal_cuenta := (x.saldo / nvl(v_cotizacion, 0)* -1);
        else
          v_sal_cuenta := x.saldo / nvl(v_cotizacion, 0);
        end if;
      else        
        v_cotizacion := pag_gen.fu_obt_cotizacion(x.cod_moneda, pae_cnf.fu_obt_fec_actual(1));
        if x.cod_modulo= 4 and x.saldo < 0 then
           v_sal_cuenta := (x.saldo * nvl(v_cotizacion, 0)* -1);
        else
            v_sal_cuenta := x.saldo * nvl(v_cotizacion, 0);
        end if;
      end if;
    end if;
    v_tot_deuda := nvl(v_tot_deuda,0) + nvl(v_sal_cuenta,0);
  end loop;
  RETURN v_tot_deuda;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;
END;
/
