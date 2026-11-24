create or replace function it.fu_obt_tas_efe_pizarra
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
     from cr_piz_plazos_his c, cr_piz_montos a
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
    and c.ano = (select max(x.ano)
                  from cr_piz_plazos_his x
                 where x.cod_modulo = c.cod_modulo
                   and x.cod_modalidad = c.cod_modalidad
                   and x.cod_moneda = c.cod_moneda
                   and x.mto_desde = c.mto_desde
                   and x.PLZ_DESDE = c.plz_desde
                   and x.TIP_CAPITALIZACION = p_tipo_capitalizacion
                   and nvl(x.COD_SUB_MODALIDAD,999) = nvl(c.COD_SUB_MODALIDAD,999))
     and c.mes = (select max(x.mes)
                  from cr_piz_plazos_his x
                 where x.cod_modulo = c.cod_modulo
                   and x.cod_modalidad = c.cod_modalidad
                   and x.cod_moneda = c.cod_moneda
                   and x.mto_desde = c.mto_desde
                   and x.PLZ_DESDE = c.plz_desde
                   and x.TIP_CAPITALIZACION = p_tipo_capitalizacion
                   and nvl(x.COD_SUB_MODALIDAD,999) = nvl(c.COD_SUB_MODALIDAD,999)
                   and x.ano = c.ano);
   Exception
    /* when no_data_found then
           raise_application_error(-20001,'No existe tasa efectiva.');*/
      when too_many_rows then
           raise_application_error(-20001,'TASA EFECTIVA Duplicada en la Pizarra de Productos. Tip. capit. '
                                           ||p_tipo_capitalizacion||' mod '||p_cod_modulo
                                           ||' mad '||p_cod_modalidad|| ' mon '|| p_cod_moneda
                                           ||' plazo '||p_plazo);
   end;

   return v_tasa_efectiva;
end fu_obt_tas_efe_pizarra;
/

