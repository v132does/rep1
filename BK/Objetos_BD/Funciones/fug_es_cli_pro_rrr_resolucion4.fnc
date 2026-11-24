create or replace function it.fug_es_cli_pro_rrr_resolucion4 (p_cod_persona ge_clientes.cod_persona%type,
                                                     p_nro_cuenta  ge_cuentas.nro_cuenta%type default null) return varchar2 is

--Proposito: --S-identificar clientes con productos exclusivos de COVID-19
             --A--con Productos COVID-19 y Otros
             --N--Sin productos COVID-10

v_es_cli_pro_3R_res4    varchar2(1);
v_cod_persona           ge_clientes.cod_persona%type := p_cod_persona;

begin

    begin
      SELECT DISTINCT 'S'
        into v_es_cli_pro_3R_res4
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
         and o.tip_renovacion in ('R','N','E') --Solo 3R Resol 4 - R-efinanciado - reNovado- rEnovado
         and nvl(g.cod_sub_modalidad,nvl(c.cod_sub_modalidad,-1)) = nvl(c.cod_sub_modalidad,-1)
         and i.cod_persona = v_cod_persona
         and (o.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
         and g.val_parametro = 'S';
    exception
      when others then
        v_es_cli_pro_3R_res4 := null;
    end;

  return nvl(v_es_cli_pro_3R_res4,'N');

 exception
    when others then
       v_es_cli_pro_3R_res4 := 'N';
       return v_es_cli_pro_3R_res4;
end fug_es_cli_pro_rrr_resolucion4;
/

