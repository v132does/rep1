create or replace function it.fug_obt_des_ent_persona(p_cod_persona in varchar2, p_tipo in varchar2) return varchar2 is
--Obtiene el codigo y descripcion de los entes asociados a una persona--
--Creado por : Rbpa / 19/01/2015--

--Variables--
v_des_ent_persona varchar2(4000);
v_nom_tip_ente ba_cod_referencias.significado%type;
--Cursores--
cursor c_personas is
  select a.cod_ente, a.descripcion
    from ge_entes a
   where a.tipo = p_tipo
     and a.cod_persona = p_cod_persona;

--Ciclo Principal--
begin
  v_des_ent_persona := null;
  for det in c_personas loop
      v_des_ent_persona := v_des_ent_persona||det.cod_ente||'-'||fue_obt_nom_ente(det.cod_ente)||';';
  end loop;
  if v_des_ent_persona is not null then
     v_nom_tip_ente := fue_obt_des_refcodes('TIP_ENTE',p_tipo);
     v_des_ent_persona := 'Persona: '||p_cod_persona||' con registros en '||'TIPO:'||v_nom_tip_ente||'='||v_des_ent_persona;
  end if;
  return v_des_ent_persona;
  exception
    when others then
          raise_application_error(-20000,'Error al traer descripcion de ente para persona '||p_cod_persona||'-'||sqlerrm);
end;
/

