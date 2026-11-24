CREATE OR REPLACE PROCEDURE IT.PRH_ACT_PROVISION (
  p_can_dias       rh_vacaciones.can_dias%type,
  p_monto          rh_vacaciones.monto%type,
  p_cod_persona    rh_provisiones.cod_persona%type,
  p_per_desde      rh_provisiones.per_desde%type,
  p_per_hasta      rh_provisiones.per_hasta%type,
  p_tipo           varchar2)
IS
  v_can_dias       rh_vacaciones.can_dias%type;
  v_dia            rh_vacaciones.can_dias%type;
  v_monto          rh_vacaciones.monto%type;
  v_haber          rh_vacaciones.monto%type;
  v_debe           rh_vacaciones.monto%type;
  v_acreditar      rh_vacaciones.monto%type;
  v_per_desde      rh_provisiones.per_desde%type;
  v_per_hasta      rh_provisiones.per_desde%type;
BEGIN
  v_acreditar := 0;
  v_monto     := p_monto;
  v_can_dias  := p_can_dias;
  v_per_desde := p_per_desde;
  v_per_hasta := p_per_hasta;
  ---
  while v_monto > 0 loop
     begin
       select nvl(mto_haber,0), nvl(mto_debe,0), nvl(dia_debe,0)
       into   v_haber, v_debe, v_dia
       from   rh_provisiones
       where  cod_persona = p_cod_persona
       and    per_desde = v_per_desde
       and    per_hasta = v_per_hasta;
     exception
       when no_data_found then
        raise_application_error(-20000,
        'No existe periodo '||to_char(v_per_desde)||'-'||to_char(v_per_hasta)||' empleado '||p_cod_persona);
     end;          
     --- Actualizar provision
     if v_monto >= v_haber then
        v_acreditar := v_haber;
     else
        v_acreditar := v_monto;
     end if;
     v_monto := v_monto - v_acreditar;
     ---
     if p_tipo = 'A' then
        v_debe := v_debe + v_monto;
        v_dia  := v_dia + v_can_dias;
     else
        v_debe := v_debe - v_monto;
        if v_can_dias >= v_dia then
           v_can_dias := v_can_dias - v_dia;
        else
           v_dia  := v_dia - v_can_dias;
        end if;
     end if;
     ---
     update rh_provisiones
     set dia_debe = v_dia,
         mto_debe = v_debe
     where cod_persona = p_cod_persona
     and per_desde = v_per_desde
     and per_hasta = v_per_hasta;
     IF sql%notfound THEN
        raise_application_error(-20000,
        'No pudo actualizarse provision periodo '||to_char(v_per_desde)||' empleado '||p_cod_persona);
     END IF;
     ---
     v_per_desde := v_per_desde + 1;
     v_per_hasta := v_per_hasta + 1;
     if p_tipo = 'A' then
        v_can_dias  := 0;
     end if;
  end loop;
END PRH_ACT_PROVISION;
/

