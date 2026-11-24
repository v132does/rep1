create or replace function it.fug_es_cli_pro_resolucion4 (p_cod_persona ge_clientes.cod_persona%type,
                                                          p_nro_cuenta  ge_cuentas.nro_cuenta%type default null) return varchar2 is

--Proposito: --S-identificar clientes con productos exclusivos de COVID-19
             --A--con Productos COVID-19 y Otros
             --N--Sin productos COVID-10

v_tie_pro_res4       varchar2(1);
v_tie_pro_no_res4    varchar2(1);

v_es_cli_pro_res4    varchar2(1);
v_cod_persona         ge_clientes.cod_persona%type := p_cod_persona;
begin

    begin
      SELECT DISTINCT 'S'
        into v_tie_pro_res4
        FROM pr_cta_prestamos o, GE_PAR_DINAMICOS G, ge_cuentas c, ge_cta_clientes i
       WHERE G.PARAMETRO = 'COD_MAD_RESOLUCION04'
         AND G.COD_MODULO = O.COD_MODULO
         AND G.COD_MODALIDAD = O.COD_MODALIDAD
         and o.nro_cuenta = i.nro_cuenta
         AND o.COD_MODULO = i.COD_MODULO
         AND o.COD_MODALIDAD = i.COD_MODALIDAD
         and o.nro_cuenta = c.nro_cuenta
         AND o.COD_MODULO = c.COD_MODULO
         AND o.COD_MODALIDAD = c.COD_MODALIDAD
         and o.estado not in ('N','I')
         and nvl(g.cod_sub_modalidad,nvl(c.cod_sub_modalidad,-1)) = nvl(c.cod_sub_modalidad,-1)
         and i.cod_persona = v_cod_persona
         and (o.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
         and g.val_parametro = 'S';
    exception
      when others then
        v_tie_pro_res4 := null;
    end;

    begin
      SELECT DISTINCT 'S'
        into v_tie_pro_no_res4
        FROM ge_cla_operaciones g, ge_cuentas c , ge_cta_clientes i, ge_est_cuentas e
       where i.cod_persona = v_cod_persona
         and (c.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
         and c.nro_cuenta = i.nro_cuenta
         AND c.COD_MODULO = i.COD_MODULO
         AND c.COD_MODALIDAD = i.COD_MODALIDAD
         and c.cod_modulo = e.cod_modulo
         and c.cod_modalidad = e.cod_modalidad
         and c.estado = e.estado
         and e.activo = 'S'
         and g.nro_cuenta = c.nro_cuenta
         and g.cod_modulo = c.cod_modulo
         and g.cod_modalidad = c.cod_modalidad
         and i.relacion = 'P'
         and not exists
               (select 1
                  from ge_par_dinamicos g
                 where g.parametro = 'COD_MAD_RESOLUCION04'
                   and g.cod_modulo = c.cod_modulo
                   and g.cod_modalidad = c.cod_modalidad
                   and g.val_parametro = 'S'
                   and nvl(g.cod_sub_modalidad,nvl(c.cod_sub_modalidad,-1)) = nvl(c.cod_sub_modalidad,-1));
    exception
      when others then
        v_tie_pro_no_res4 := null;
    end;

  If nvl(v_tie_pro_res4,'X') =  'S' and nvl(v_tie_pro_no_res4,'X') = 'S' then
     v_es_cli_pro_res4 := 'A';
  elsif nvl(v_tie_pro_res4,'X') = 'S' and nvl(v_tie_pro_no_res4,'X') = 'X' then
     v_es_cli_pro_res4 := 'S';
  elsif  nvl(v_tie_pro_res4,'X') = 'X' and nvl(v_tie_pro_no_res4,'X') = 'S' then
     v_es_cli_pro_res4 := 'N';
  elsif nvl(v_tie_pro_res4,'X') = 'X' and nvl(v_tie_pro_no_res4,'X') = 'X' then
     v_es_cli_pro_res4 := 'N';
  End if;

  return nvl(v_es_cli_pro_res4,'N');

 exception
    when others then
       v_es_cli_pro_res4 := 'N';
       return v_es_cli_pro_res4;
end;
/

