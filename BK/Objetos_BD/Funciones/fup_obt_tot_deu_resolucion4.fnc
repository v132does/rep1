create or replace function it.fup_obt_tot_deu_resolucion4 (p_cod_persona ge_clientes.cod_persona%type,
                                                        p_nro_cuenta  ge_cuentas.nro_cuenta%type default null) return number is


v_tot_ope_resolucion4     ge_cla_operaciones.tot_deu_real%type;
v_cod_persona             ge_clientes.cod_persona%type := p_cod_persona;

begin

    begin
      SELECT sum(o.tot_deu_real)
        into v_tot_ope_resolucion4
        FROM ge_cla_operaciones o, GE_PAR_DINAMICOS G
       WHERE G.PARAMETRO = 'COD_MAD_RESOLUCION04'
         AND g.val_parametro = 'S'
         AND G.COD_MODULO = O.COD_MODULO
         AND G.COD_MODALIDAD = O.COD_MODALIDAD
         AND o.COD_MODULO = g.COD_MODULO
         AND o.COD_MODALIDAD = g.COD_MODALIDAD
         and o.cod_persona = v_cod_persona
         and (o.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null);
    exception
      when others then
        v_tot_ope_resolucion4 := 0;
    end;

    return nvl(v_tot_ope_resolucion4,0);

 exception
    when others then
       v_tot_ope_resolucion4 := 0;
       return v_tot_ope_resolucion4;
end;
/

