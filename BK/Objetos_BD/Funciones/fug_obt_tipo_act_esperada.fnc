CREATE OR REPLACE FUNCTION IT.fug_obt_tipo_act_esperada(p_cod_persona IN cr_act_esperadas.cod_persona%type,
                                                  p_fecha       IN cr_act_esperadas.fecha%type)
  RETURN VARCHAR2 IS
  v_perfil      varchar2(1);
  v_fec_menor   cr_act_esperadas.fecha%type;
  v_fec_mayor   cr_act_esperadas.fecha%type;
  v_cod_persona ba_personas.cod_persona%type;
BEGIN
  --
  Begin
    -- Verifico si existe más de un perfil para una persona
    -- Si no hay por defecto es D ya que existe una sola vez
    select cod_persona, min(fecha), max(fecha)
    into v_cod_persona, v_fec_menor, v_fec_mayor
    from cr_act_esperadas
    where cod_persona = p_cod_persona
    group by cod_persona;
    --having count(*) > 1;
    -- Verificar si la fecha del perfil es la primera si es asi se asigna D
    if trunc(v_fec_menor) = trunc(p_fecha) then
      v_perfil := 'D';
    elsif trunc(v_fec_mayor) = trunc(p_fecha) then
      -- Verificar si la fecha del perfil es la ultima si es asi asignar M ya que se supone
      -- que ya existe un perfil D
      v_perfil := 'M';
    else
      -- Si la fecha del perfil no es la primera ni la ultima entonces no se informa y va con N
      -- En la vista solo se informa M y D
      v_perfil := 'N';
    end if;
    --
  exception
    when no_data_found then
      v_perfil := 'D';
  end;
  --
  return v_perfil;
  --
EXCEPTION
  WHEN others THEN
    raise_application_error(-20000, 'Ocurrio un error '||sqlerrm);
END;
/

