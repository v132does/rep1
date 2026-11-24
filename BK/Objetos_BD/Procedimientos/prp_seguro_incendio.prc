CREATE OR REPLACE PROCEDURE IT.PRP_SEGURO_INCENDIO is
  --Proceso para actualizar Seguros de Incendio que Vecieron y no se renovaron --- DM 10-07-2012
  v_fec_actual date := pag_cal.fu_obt_fec_actual(6);
  v_cod_gar_hipotecaria number := fug_obt_pardinamico('COD_GAR_HIPOTECARIA',6);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  v_count number;

  cursor c_seguros is
  select p.nro_cuenta,
         p.nro_solicitud,
         v.fec_vto_seguro
  from pr_cta_prestamos p,
       (select g.nro_cuenta, max(g.fec_ini_vigencia) fec_vto_seguro from pr_cta_gastos g
        where g.cod_transaccion = 1520 group by g.nro_cuenta) v
   where p.nro_cuenta = v.nro_cuenta
---     and p.estado = 'C'                 --Vigentes --- puede generar vencidos tambien --- DM
     and p.nro_cuenta in (10004410,10013407,10018607,10031208,10034307,10038407,10042707,10075207,10100110,10125510,
10138010,10163506,10222309,10226908,10244409,10510207,10518207,166088650,166122777,166124303,366077058,466032757,
466137648,666043973,666105014,666131228,666148236,70017908,70029207,70052206,70059510,70105209,70143909,70155209,
766044122,766059898,766071758,766075699,766088413,766090531,766105342,766122824,766123090,766125882,766133230,766137864,
766138364,766147649,80004607,1366060415,1366109066,1566043832,1766076378,2166049230,2266131010,2566130965 )
---     and v.fec_vto_seguro = v_fec_actual   ---- porque necesito tomar otras cuentas vencidas DM
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

      if nvl(v_count,0) <> 0 then
         --Proceso de Renovación por Cuenta --- Si no encuentra no hace nada --- DM
         prp_ren_seguro(seg.nro_cuenta);
      end if;
   end loop;
exception
   when others then
      raise_application_error(-20000,'Cta: '||v_nro_cuenta||' '||sqlerrm);
end PRP_SEGURO_INCENDIO;
/

