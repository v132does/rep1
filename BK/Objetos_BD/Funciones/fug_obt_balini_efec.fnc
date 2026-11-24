CREATE OR REPLACE FUNCTION IT.fug_obt_balini_efec(p_ano    IN varchar2,
                                               p_mes    IN varchar2,
                                               p_moneda in varchar2)
  RETURN NUMBER IS
  v_monto_inicial lc_ope_efectivos.monto%type;
begin

  begin
     
    --select  sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0)))
    Select sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-decode(a.mes,12,0,nvl(a.cre_mon_rubro,0)))
      into v_monto_inicial
      from cb_rubros r, cb_sal_oficinas_his a
     where r.cod_rubro in
           ('111101010202005', '111101010208905', '111101010262705',
            '111101010262105', '111101010206405', '111101010206905',
            '111101010207605', '111101010207905', '111101010206605',
            '111101010205905', '111101030100103', '111101010209105',
            '111101010210405', '111101010262205', '111101010206205',
            '111101010200103', '111101010207005', '111101010205805',
            '111101010209705', '111101010210305', '111101010206005',
            '111101030100105', '111101010207705', '111101010209305',
            '111101010210105', '111101010206105', '111101010209505',
            '111101010210205', '111101010200105', '111101010200117',
            '111101030100117')
       and r.cod_rubro = a.cod_rubro
       and a.mes = p_mes
       and a.ano = p_ano
       and r.cod_moneda = p_moneda;
           
  exception
    when no_data_found then
      v_monto_inicial := 0;
  end;

  return(v_monto_inicial);

exception
  when no_data_found then
    raise_application_error(-20000, 'Error al Obtener siguiente nro. CDA');
  
end;
/

