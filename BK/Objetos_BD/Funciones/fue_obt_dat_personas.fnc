CREATE OR REPLACE FUNCTION IT.FUE_OBT_DAT_PERSONAS (p_cod_persona varchar2, p_tipo varchar2) RETURN varchar2 IS
  v_nro_documento varchar2(100);
  v_nro_doc_sin_dv varchar2(100);
  v_tip_iva ba_personas.tip_iva%type;
  v_tip_persona ba_personas.tipo%type;
  v_dig_verificador varchar2(5);
  v_tip_gen_extracto varchar2(1);
  v_dir_cliente       varchar2(500);
  v_des_pais          ba_direcciones.direccion%type;
  v_des_ciudad        ba_ciudades.descripcion%type;
  v_des_barrio        ba_barrios.descripcion%type;
  v_tel_cliente       ge_ext_clientes.telefono%type;
  v_tip_envio         ge_dir_envios.tip_envio%type;
  v_ind_web varchar2(1);
  v_piso ba_direcciones.piso%type;
  v_departamento ba_direcciones.departamento%type;
  v_edificio  ba_direcciones.edificio%type;
  v_direccion varchar2(500);

BEGIN
  if p_tipo = 'RUC' then
    begin
      select nro_documento, tip_iva, tipo
        into v_nro_documento, v_tip_iva, v_tip_persona
        from ba_personas
       where cod_persona = p_cod_persona;
    exception
      when others then
        RAISE_APPLICATION_ERROR( -20000, 'No se encuentra el código de persona');
    end;

    if v_tip_persona = 'F' then
       begin
         select DECODE(NVL(v_tip_iva,'NC'),'NC',v_nro_documento,v_nro_documento||'-'||fue_obt_ruc_dig_verificador(v_NRO_DOCUMENTO))
           into v_nro_documento
           from ba_per_fisicas f
          where cod_persona = p_cod_persona;

          if instr(v_nro_documento,'-') > 0 then
             v_nro_doc_sin_dv   := substr(v_nro_documento,1,instr(v_nro_documento,'-')-1);
             v_dig_verificador := substr(v_nro_documento,-1);
          else
            if v_tip_iva = 'NC' then
               v_nro_doc_sin_dv := v_nro_documento;
               v_dig_verificador := null;
            else
               v_nro_doc_sin_dv   := v_nro_documento;
               v_dig_verificador := fue_obt_ruc_dig_verificador(v_nro_documento);
            end if;
          end if;
       exception
          when others then
            v_nro_doc_sin_dv:= v_nro_documento;
            v_dig_verificador := 0;
       end;
    else
       begin
         if instr(v_nro_documento,'-') > 0 then
            v_nro_doc_sin_dv   := substr(v_nro_documento,1,instr(v_nro_documento,'-')-1);
            v_dig_verificador := substr(v_nro_documento,-1);
         end if;
         exception
           when others then
             v_nro_doc_sin_dv := v_nro_documento;
             v_dig_verificador := 0;
         end;

    end if;

    if v_dig_verificador is null then
      return v_nro_doc_sin_dv;
    elsif v_dig_verificador <> '-1' then
      return v_nro_doc_sin_dv ||'-'||v_dig_verificador;
    else
      return v_nro_doc_sin_dv;
    end if;
  elsif p_tipo = 'DIR' THEN
    begin
      select val_parametro
        into v_tip_gen_extracto
        from ba_per_dat_adicionales t
       where t.parametro = 'TIP_GEN_EXTRACTOS'
         and cod_persona = p_cod_persona;
    exception
      when others then
        v_tip_gen_extracto := 'I';
    end;

    if nvl(v_tip_gen_extracto, 'I') = 'C' then
      begin
        SELECT substr(d.direccion,1,89),
               p.descripcion des_pais, c.descripcion des_ciudad, b.descripcion des_barrio,
               d.piso,d.departamento,d.edificio
          INTO v_dir_cliente,
               v_des_pais,v_des_ciudad,  v_des_barrio,
               v_piso,v_departamento,v_edificio
          FROM ba_barrios b, ba_ciudades c, ba_paises p,
               ba_direcciones d, ge_dir_envios e
         where e.cod_persona = p_cod_persona
           and e.nro_cuenta is null
           and p.cod_pais(+) = d.cod_pais
           and c.cod_pais(+) = d.cod_pais
           and c.cod_ciudad(+) = d.cod_ciudad
           and b.cod_pais(+) = d.cod_pais
           and b.cod_ciudad(+) = d.cod_ciudad
           and b.cod_barrio(+) = d.cod_barrio
           and d.cod_persona(+) = e.cod_persona
           and d.cod_direccion(+) = e.referencia;
      exception
        when others then
          BEGIN
            SELECT substr(d.direccion,1,89),
                   p.descripcion des_pais, c.descripcion des_ciudad, b.descripcion des_barrio,
                   d.piso,d.departamento,d.edificio
              INTO v_dir_cliente,
                   v_des_pais,v_des_ciudad,  v_des_barrio,
                   v_piso,v_departamento,v_edificio
              FROM ba_barrios b, ba_ciudades c, ba_paises p,
                   ba_direcciones d
             where d.cod_persona = p_cod_persona
               and p.cod_pais(+) = d.cod_pais
               and c.cod_pais(+) = d.cod_pais
               and c.cod_ciudad(+) = d.cod_ciudad
               and b.cod_pais(+) = d.cod_pais
               and b.cod_ciudad(+) = d.cod_ciudad
               and b.cod_barrio(+) = d.cod_barrio
               and nvl(d.principal, 'N') = 'S';
          EXCEPTION
            WHEN OTHERS THEN
              v_dir_cliente := NULL;
          END;
      end;
    else
      begin
        SELECT substr(d.direccion,1,89),
               p.descripcion des_pais, c.descripcion des_ciudad, b.descripcion des_barrio,
               d.piso,d.departamento,d.edificio
          INTO v_dir_cliente,
               v_des_pais,v_des_ciudad,  v_des_barrio,
               v_piso,v_departamento,v_edificio
          FROM ba_barrios b, ba_ciudades c, ba_paises p,
               ba_direcciones d
         where d.cod_persona = p_cod_persona
           and p.cod_pais(+) = d.cod_pais
           and c.cod_pais(+) = d.cod_pais
           and c.cod_ciudad(+) = d.cod_ciudad
           and b.cod_pais(+) = d.cod_pais
           and b.cod_ciudad(+) = d.cod_ciudad
           and b.cod_barrio(+) = d.cod_barrio
           and nvl(d.principal, 'N') = 'S';
      exception
        when others then
           v_dir_cliente := null;
      end;
    end if;


      --se obtiene el piso-edificio-dpto si es que no se retiene el extracto
    if v_piso is not null then
       v_direccion := ' Piso: '||v_piso;
    end if;

    if v_departamento is not null then
       v_direccion:= v_direccion||' Dpto.: '||v_departamento;
    end if;

    if v_edificio is not null then
       v_direccion:= v_direccion||' Edificio: '||v_edificio;
    end if;

    v_dir_cliente := substr(v_dir_cliente||v_direccion,1,500);

    return v_dir_cliente;
  elsif p_tipo = 'WEB' then
    begin
      select distinct 'S'
        into v_ind_web
        from bw_ope_claves p
       where p.est_clave = 'M'
         and p.tip_clave = 'A'
         and cod_persona = p_cod_persona;
    exception
      when others then
        return 'N';
    end;
    return nvl(v_ind_web, 'N');
  else
    return fue_obt_tel_principa(p_cod_persona);
  end if;
END;
/

