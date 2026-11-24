CREATE OR REPLACE PROCEDURE IT.PRP_PRO_REN_SEG_INCENDIO is
  --Proceso de Renovación Automática de Seguros de Incendio que Vencen en el Día
  v_fec_actual date := pag_cal.fu_obt_fec_actual(6);
  v_cod_gar_hipotecaria number := fug_obt_pardinamico('COD_GAR_HIP_VIVIENDA',6);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  v_count number;

  cursor c_seguros is
	select p.nro_cuenta,
         p.nro_solicitud,
         v.fec_vto_seguro
    from pr_cta_prestamos p,
         (select g.nro_cuenta,
                 max(g.fec_ini_vigencia) fec_vto_seguro
            from pr_cta_gastos g
           where g.cod_transaccion = 1520
           group by g.nro_cuenta) v
   where p.nro_cuenta = v.nro_cuenta
     and p.estado not in ('I', 'N')       -- 05/09/2013 - EC - GC DC 2504 
     and v.fec_vto_seguro <= v_fec_actual --'11/12/2015'  /* Para que considere días no hábiles. CB 07/05/2012 - AP 2688*/
     and not exists (select 1
                                  from ge_cta_dat_adicionales da
                                  where da.nro_cuenta = p.nro_cuenta
                                  and da.parametro = 'EVI_REN_AUT_SEG_INCENDIO' 
                                  and nvl(da.val_parametro, 'N') = 'S')
     and exists (select 1
            from pr_cta_garantias x
           where x.nro_cuenta = p.nro_cuenta
             and x.cod_garantia = v_cod_gar_hipotecaria) --Que tenga Garantia Hipotecaria       
   order by p.nro_cuenta;
begin

   --Inicializar variables
   pae_cnf.pr_set_variables(fug_ini_hora(sysdate,'hh24:mi:ss'),0);

   for seg in c_seguros loop
      v_nro_cuenta := seg.nro_cuenta;
      --Verificar que este registrado el cargo por Seguro de Incendio en PR_SOL_CARGOS
      select count(1)
        into v_count
        from pr_sol_cargos c
       where c.nro_solicitud = seg.nro_solicitud
         and c.cod_transaccion = 1520;

      if nvl(v_count,0) = 0 then
         raise_application_error(-20000,'No se encuentra el Cargo en PR_SOL_CARGOS, Cuenta: '||seg.nro_cuenta||', Nro.Solicitud: '||seg.nro_solicitud);
      end if;
      --Proceso de Renovación por Cuenta
      prp_ren_seg_incendio(seg.nro_cuenta);
   end loop;
exception
   when others then
      raise_application_error(-20000,'Cta: '||v_nro_cuenta||' '||sqlerrm);
end PRP_PRO_REN_SEG_INCENDIO;
/

