create or replace function it.fug_obt_tas_efe_pizarra
  (p_cod_modulo            IN NUMBER,
   p_cod_modalidad         IN NUMBER,
   p_cod_moneda            IN VARCHAR2,
   p_monto                 in number,
   p_plazo                 in number,
   p_tipo_capitalizacion   in number,
   p_cod_sub_modalidad     in number default null)
   
RETURN number is
v_tasa_efectiva number;
BEGIN
   /* buscar la tasa efectiva*/
   Begin
   SELECT distinct c.tas_efectiva
     into v_tasa_efectiva
     from cr_piz_plazos_tmp c, cr_piz_montos a
    where c.cod_modulo = p_cod_modulo
    and c.cod_modalidad = p_cod_modalidad
    and c.cod_moneda = p_cod_moneda
    and c.plz_desde <= p_plazo
    and c.plz_hasta >= p_plazo
    and c.tip_capitalizacion = p_tipo_capitalizacion
    and nvl(c.cod_sub_modalidad,999) = nvl(p_cod_sub_modalidad,999)
    and p_monto between a.mto_desde and a.mto_hasta
    and c.tas_efectiva is not null
    and c.mto_desde = a.mto_desde
    and c.cod_modulo = a.cod_modulo
    and c.cod_modalidad = a.cod_modalidad
    and c.cod_moneda = a.cod_moneda
    and c.cod_sub_modalidad = a.cod_sub_modalidad
    and (c.ano|| mes)= (select max(ano||mes) from cr_piz_plazos_tmp tm
                           where tm.cod_modulo = p_cod_modulo
                            and tm.cod_modalidad = p_cod_modalidad
                            and tm.cod_moneda = p_cod_moneda
                            and tm.plz_desde <= p_plazo
                            and tm.plz_hasta >= p_plazo
                            and tm.tip_capitalizacion = p_tipo_capitalizacion
                            and tm.tas_efectiva is not null);              
   Exception
      when too_many_rows then
           raise_application_error(-20001,'TASA EFECTIVA Duplicada en la Pizarra de Productos. Tip. capit. '
                                           ||p_tipo_capitalizacion||' mod '||p_cod_modulo
                                           ||' mad '||p_cod_modalidad|| ' mon '|| p_cod_moneda
                                           ||' plazo '||p_plazo);
   end;

   return v_tasa_efectiva;
end fug_obt_tas_efe_pizarra;
/
