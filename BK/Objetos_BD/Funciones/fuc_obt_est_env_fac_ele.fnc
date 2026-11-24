create or replace function it.fuc_obt_est_env_fac_ele
  return varchar2 is
  v_est_ini_cie     varchar2(1) := 'S';
  v_cod_pro_ini     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_PRO_INICIO');
  v_cod_pro_cie     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_PRO_FIN');
begin

  begin
  select c.estado
           into v_est_ini_cie
    from (
           select 'N' estado from ge_procesos i
            where i.cod_proceso = v_cod_pro_cie
            and (i.hor_inicio is null and i.hor_fin is null)
            and exists(select 1 from ge_procesos f
            where f.cod_proceso = v_cod_pro_ini
            and (f.hor_inicio is not null and f.hor_fin is not null))
            union
            select 'S' from ge_procesos i
            where i.cod_proceso = v_cod_pro_cie
            and (i.hor_inicio is NOT null and i.hor_fin is null)--Si se esta ejecutando el cierre
            union all
            select 'S' from ge_procesos i
            where i.cod_proceso = v_cod_pro_cie
            and (i.hor_inicio is not null and i.hor_fin is not null)
            and exists(select 1 from ge_procesos f
            where f.cod_proceso = v_cod_pro_ini
            and (f.hor_inicio is null and f.hor_fin is null))--Si se termino el cierre y el inicio aun no inicio
            union all
            select 'S' from ge_procesos i
            where i.cod_proceso = v_cod_pro_ini
            and (i.hor_inicio is NOT null and i.hor_fin is null)  --Si se esta ejecutando el inicio;
           ) c;
           
  exception
    when others then
       v_est_ini_cie := 'S';
  end;

     return v_est_ini_cie;

end fuc_obt_est_env_fac_ele;
/

