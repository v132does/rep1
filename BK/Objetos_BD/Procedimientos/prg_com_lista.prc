CREATE OR REPLACE PROCEDURE IT.prg_com_lista IS
  -- Requerimiento: CNFNORMA-65
  -- Creado    : 07/10/2016
  -- Propósito : Comparación de Base de Cliente vs. Lista cumplimiento

  --Variables--
  v_exi_bbva    varchar2(1);
  v_cod_persona varchar2(4000);
  v_error       varchar2(4000);

  --Cursores--
  CURSOR c_per_listas IS
    SELECT distinct(upper(fug_eli_acentos(a.nombre)))nombre
      FROM ge_per_listas_tmp a
     WHERE nvl(a.procesado, 'N') = 'N'
       AND a.nombre IS NOT NULL;

  CURSOR c_per_fisicas(p_nombre varchar2) IS
    SELECT f.cod_persona, f.pri_nombre, f.seg_nombre, f.pri_apellido
      FROM ba_per_fisicas f
     where f.pri_nombre||' '||f.pri_apellido like '%'||p_nombre||'%'
           or f.seg_Nombre||' '||f.Pri_Apellido like '%'||p_nombre||'%';

  CURSOR c_per_juridicas(p_nombre varchar2) IS
    SELECT j.cod_persona, j.raz_social, j.nom_comercial
      FROM ba_per_juridicas j
     WHERE j.raz_social like '%'||p_nombre||'%' OR
           j.nom_comercial like '%'||p_nombre||'%';
BEGIN
  
  FOR lis in c_per_listas LOOP
    v_exi_bbva    := 'N';
    v_cod_persona := null;
    v_error       := null;
    --Persona Fisica--
    FOR cli in c_per_fisicas(lis.nombre) LOOP
      begin
        if v_cod_persona is null then
          v_cod_persona := cli.cod_persona;
        else
          v_cod_persona := v_cod_persona||';'||cli.cod_persona;
        end if;
      exception
        when others then
          v_error := 'Verificar error al buscar persona. '||sqlerrm;
      end;
      v_exi_bbva := 'S';
    END LOOP;

    --Persona Juridica--
    FOR jur in c_per_juridicas(lis.nombre) LOOP
      begin
        if v_cod_persona is null then
          v_cod_persona := jur.cod_persona;
        else
          v_cod_persona := v_cod_persona||';'||jur.cod_persona;
        end if;
        exception
          when others then
            v_error := 'Verificar error al buscar persona. '||sqlerrm;
        end;
      v_exi_bbva := 'S';
     END LOOP;

    IF v_exi_bbva = 'S' THEN
      UPDATE ge_per_listas_tmp x
         SET x.exi_bbva    = 'S',
             x.cod_persona = v_cod_persona,
             x.procesado   = 'S',
             x.men_error  = v_error
       WHERE upper(x.nombre) = lis.nombre;
    ELSE
      UPDATE ge_per_listas_tmp x
         SET x.exi_bbva    = 'N',
             x.procesado   = 'S'
       WHERE upper(x.nombre) = lis.nombre;
    END IF;
  END LOOP;
   --Importación de archivo--
    prg_gen_arc_lista;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'Error al buscar Personas en Lista'||sqlerrm);
END;
/

