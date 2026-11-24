CREATE OR REPLACE FUNCTION IT.fup_obt_sal_librador
(
   p_cod_persona     in       ge_cta_clientes.cod_persona%type,
   p_nro_documento   in       ba_personas.nro_documento%type
) RETURN NUMBER IS
   v_saldo             pr_cuotas.sal_capital%TYPE;
BEGIN
        select sum(nvl( b.monto,0) )
          into v_saldo
        from pr_cta_prestamos pr, ge_cta_clientes cc, ba_personas p,  (Select c.nro_referencia, c.monto, c.nro_cheque
                                   from  ge_che_custodias c, pr_rel_chq_lib r, pr_chq_libradores cl
                                  where r.cod_banco     = c.cod_banco
                                    and r.nro_cheque    = c.nro_cheque
                                    and r.cta_libradora = c.cta_libradora
                                    and r.nro_documento = cl.nro_documento
                                    and r.nro_documento = p_nro_documento ) b
       where p.cod_persona=cc.cod_persona
         and pr.nro_cuenta=cc.nro_cuenta
         and pr.cod_modalidad=608
         and pr.nro_cuenta = b.nro_referencia
         and pr.estado<>'N'
         and p.cod_persona      = p_cod_persona;
      return nvl(v_saldo,0);
exception
  when no_data_found then
      return nvl(v_saldo,0);
END;
/

