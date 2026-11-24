CREATE OR REPLACE PROCEDURE IT.prt_cli_preembozado IS

  CURSOR c_cli IS
  SELECT *
    FROM ta_cli_preembozado_tmp a;

  v_existe varchar2(1) := 'N';
  VCODIGO  Number(2); --para almacenar el codigo siguiente en direcciones

BEGIN
  BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
  FOR c IN c_cli LOOP
    --valida si ya existe una direccion igual para la persona
    BEGIN
      select 'S'
        into v_existe
        from ba_direcciones b
       where b.cod_persona = c.cod_persona
         and b.direccion = c.direccion
         /*and (b.principal = 'S' or b.tipo = 'T')*/;
    EXCEPTION
      when no_data_found then
        v_existe := 'N';
    END;
    
    --obtenemos el siguiente cod_direccion para insertar
    Begin
       Select MAX(nvl(d.cod_direccion,0)) + 1
         Into VCODIGO
         From BA_DIRECCIONES D
        Where D.COD_PERSONA = c.cod_persona;
    Exception
       When NO_DATA_FOUND Then
            VCODIGO := 1;
    End;

    if v_existe = 'N' then
      /*update ba_direcciones b
         set b.principal = 'S'
       where b.cod_persona = c.cod_persona
         and b.direccion = c.direccion;
    elsif c.tipo = 'T' then*/
        INSERT INTO ba_direcciones
        (cod_persona,
         cod_direccion,
         tipo,
         principal,
         direccion,
         cod_pais,
         cod_ciudad,
         cod_barrio,
         observacion,
         numero,
         departamento,
         piso,
         edificio,
         cod_postal)
         VALUES
        (c.cod_persona,
         VCODIGO,
         c.tipo,
         'N',
         c.direccion,
         1,
         nvl(c.cod_ciudad,1),
         c.cod_barrio,
         null,
         null,
         null,
         null,
         null,
         null);
      end if;
      
      --actualizo oficial
      if c.cod_usu_oficial is not null then
        update ge_clientes g
           set g.cod_usu_oficial = c.cod_usu_oficial
         where g.cod_persona = c.cod_persona;
      end if;
      
      --actualizo promotor y correo
      if c.cod_usu_promotor is not null then
        update ba_personas g
           set g.cod_usu_promotor = c.cod_usu_promotor
         where g.cod_persona = c.cod_persona;
      end if;
      
      if c.dir_correo is not null then
        update ba_personas g
           set g.dir_correo = c.dir_correo
         where g.cod_persona = c.cod_persona;
      end if;
  END LOOP;
END;
/

