create or replace function it.fup_obt_ori_fondo(
  p_cod_modulo        pr_solicitudes.cod_modulo%type,
  p_cod_modalidad     pr_solicitudes.cod_modalidad%type,
  p_cod_moneda        pr_solicitudes.cod_moneda%type,
  p_cod_oficina       pr_solicitudes.cod_oficina%type,
  p_cod_sub_modalidad pr_solicitudes.cod_sub_modalidad%type)
return number is
  v_ori_fondo pr_solicitudes.cod_ori_fondo%type;
  v_existe varchar2(1) := 'N';
  v_cod_moneda ba_monedas.cod_moneda%type;
begin
  v_ori_fondo := fug_obt_pardinamico('COD_ORI_FON_DESEMB', p_cod_modulo, p_cod_modalidad,
                 p_cod_moneda, p_cod_oficina, p_cod_sub_modalidad);
  if v_ori_fondo is not null then
     select decode(nvl(count(*),0),0,'N','S')
       into v_existe
       from pr_fondos a
      where a.descripcion not like ('FONDOS AFD%')
        and a.cod_ori_fondo = v_ori_fondo;
     if nvl(v_existe,'N') = 'N' then
        if p_cod_moneda is null then
           begin
              select a.cod_moneda
                into v_cod_moneda
                from pr_fondos a
               where a.cod_ori_fondo = v_ori_fondo;
           exception
              when others then
                 v_cod_moneda := null;
           end;
        else
           v_cod_moneda := p_cod_moneda;
        end if;
        if v_cod_moneda is not null then
           begin
               select cod_ori_fondo
                 into v_ori_fondo
                 from pr_fondos
                where descripcion not like ('FONDOS AFD%')
                  and cod_moneda = v_cod_moneda;        
           exception
              when others then
                 v_ori_fondo := null;
           end;
        end if;
     end if;
  end if;
  return(v_ori_fondo);
end fup_obt_ori_fondo;
/

