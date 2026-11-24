CREATE OR REPLACE FUNCTION IT.FUE_VAL_PERSONAS (P_COD_PERSONA IN VARCHAR2)
RETURN VARCHAR2 IS
  vmensaje varchar2(1000) := null;
  vnat ba_per_juridicas.naturaleza%type;
  vesc ba_per_fisicas.est_civil%type;
  vtip char(1);
  vcan number := 0;
  vtok char(1) := 'N';
BEGIN
  -- Debe tener cargado y marcado alguna opción en Perfil del cliente.
  begin
    select (case when ('S' in (a.fon_transferencias,
                               a.fon_salario,
                               a.fon_prestamos,
                               a.fon_vta_activos,
                               a.fon_ren_financieras,
                               a.fon_herencia,
                               a.fon_ahorro,
                               a.pro_ingresos,
                               a.pro_ahorros,
                               a.pro_ven_alq,
                               a.pro_gas_operativos,
                               a.pro_otros,
                               a.pep,
                               a.cli_frecuente,
                               a.fon_propio,
                               a.ope_giros,
                               a.ope_cambios
                               )
                            ) then 'S' else 'N' end)
    into vtok
    from cr_inf_fondos a
   where a.cod_persona = p_cod_persona;
  exception
    when others then
    null; -- si no hay registros se debe cargar.
  end;
  if vtok != 'S' then
    vmensaje := 'Es Obligatoria la carga del Perfil del Cliente antes de la apertura de cualquier Servicio o Producto.';
  end if;
  -----------------
  -- Verifico los vínculos(naturaleza y estado civil) PJ Y PF.
  begin
    select naturaleza, 'J'
      into vnat, vtip
      from ba_per_juridicas
     where cod_persona = p_cod_persona;
  exception
    when others then
    begin
      select est_civil, 'F'
        into vesc, vtip
        from ba_per_fisicas
       where cod_persona = p_cod_persona;
    exception
      when others then
      null;
    end;
  end;
  if vtip = 'J' then
    if vnat in ('SA','SRL','SEPA') then
      begin
        select count(*)
          into vcan
          from ba_vinculos a
         where a.cod_persona = p_cod_persona
           and a.tipo in ('DI','AC','S','P');

      exception
        when others then
        vcan := 0;
      end;

      if vcan < 1 then
        vmensaje := 'Para la apertura de Productos o Servicios la Persona debe tener registrado un Vínculo tipo: (Accionista, Director, Socio, Presidente).';
      end if;

    end if;
  else -- física
    if vesc = 'C' then
      begin
        select count(*)
          into vcan
          from ba_vinculos a
         where a.cod_persona = p_cod_persona
           and a.tipo = 'E'; --CONYUGE O ESPOSO/A
      exception
        when others then
        vcan := 0;
      end;

      if vcan != 1 then
        vmensaje := 'Para la apertura de Productos o Servicios la Persona debe tener registrado el Vínculo tipo Cónyuge.';
      end if;

    end if;
  end if;
  return vmensaje;
END;
/

