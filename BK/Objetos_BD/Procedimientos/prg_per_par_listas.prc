create or replace procedure it.prg_per_par_listas(p_nombre      in varchar2,
                                                  p_s_nombre    in varchar2,
                                                  p_apellido    in varchar2,
                                                  p_s_apellido  in varchar2,
                                                  p_cod_mensaje out varchar2,
                                                  p_mensaje     out varchar2) IS
  V_CANTIDAD NUMBER(10) := 0;
  v_valida   varchar2(4) := null;

BEGIN
  p_cod_mensaje := '0';
  
  /*Lóg.1:Verifica que coincidan los 2 nombres y los 2 apellidos y que el estado de la persona sea inhibido.*/
  IF upper(p_nombre) IS NOT NULL AND upper(p_s_nombre) IS NOT NULL AND
     upper(p_apellido) IS NOT NULL AND upper(p_s_apellido) IS NOT NULL THEN
     SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     WHERE pf.pri_nombre = upper(p_nombre)
       AND pf.SEG_NOMBRE = upper(p_s_nombre)
       AND pf.PRI_APELLIDO = upper(p_apellido)
       AND pf.SEG_APELLIDO = upper(p_s_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
       v_valida := 'NNAA';
  END IF;
  
  /*Lóg. 2: Verifica que coincidan los 2 nombres y primer apellido y que el estado de la 
    persona sea inhibido*/
  IF NVL(v_cantidad, 0) = 0 AND upper(p_nombre) IS NOT NULL AND
     upper(p_s_nombre) IS NOT NULL AND upper(p_apellido) IS NOT NULL THEN
    SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     where pf.pri_nombre = upper(p_nombre)
       AND pf.SEG_NOMBRE = upper(p_s_nombre)
       AND pf.PRI_APELLIDO = upper(p_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NNA';
  END IF;
  
  /*Lóg. 3: Verifica que coincidan los primer nombre, 
    primer apellido y segundo apellido y que el estado de la persona sea inhibido*/
  IF NVL(v_cantidad, 0) = 0 AND upper(p_nombre) IS NOT NULL AND
     upper(p_apellido) IS NOT NULL AND upper(p_s_apellido) IS NOT NULL THEN
    SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     where pf.pri_nombre = upper(p_nombre)
       AND pf.PRI_APELLIDO = upper(p_apellido)
       AND pf.SEG_APELLIDO = upper(p_s_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NAA';
  END IF;
  
  /*Lóg. 4: Verifica que coincidan el segundo nombre, 
   primer apellido y segundo apellido y que el estado de la persona sea inhibido */
  IF NVL(v_cantidad, 0) = 0 AND upper(p_s_nombre) IS NOT NULL AND
     upper(p_apellido) IS NOT NULL AND upper(p_s_apellido) IS NOT NULL THEN   
    SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     where pf.seg_nombre = upper(p_s_nombre)
       AND pf.PRI_APELLIDO = upper(p_apellido)
       AND pf.SEG_APELLIDO = upper(p_s_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NA';
  END IF;
  /* FIELDESK-11513 08/04/2022
  IF NVL(v_cantidad, 0) = 0 THEN
    -- Si carga solo el primer nombre y el primer apellido
    SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     where pf.pri_nombre = upper(p_nombre)
       AND pf.PRI_APELLIDO = upper(p_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NA';
  END IF;
  
  IF NVL(v_cantidad, 0) = 0 THEN
    -- Si carga solo el Segundo nombre y el Segundo apellido
    SELECT COUNT(*)
      into v_cantidad
      FROM BA_PER_FISICAS pf, ge_per_inhibidas i
     where pf.seg_nombre = upper(p_s_nombre)
       AND pf.seg_APELLIDO = upper(p_s_apellido)
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NA';
  END IF;
  */ -- fin FIELDESK-11513 08/04/2022
  
  
  /**************************************************/
  --Validación en la tabla de pesonas jurídicas--Ajustes hechos el 25/08/2022 DA-7081
  /**************************************************/  
  /*Lóg. 5: Busca en P.J ambos nombres y ambos apellidos */
  IF NVL(v_cantidad, 0) = 0 AND p_nombre IS NOT NULL  AND p_s_nombre IS NOT NULL AND p_apellido IS NOT NULL  
    AND p_s_apellido IS NOT NULL THEN    
      begin    
       SELECT COUNT(*)
        into v_cantidad
       FROM Ba_Per_Juridicas pj, ge_per_inhibidas i
       where ((upper(pj.raz_social) like
           '%'||upper(p_nombre) ||'%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%') or 
          (upper(pj.nom_comercial) like
           '%'||upper(p_nombre) ||'%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%'))
        and pj.cod_persona = i.cod_persona
        AND i.cod_causa in (Select t.val_minimo  from ba_cod_referencias t where t.dominio = 'COD_INH_LISTAS')
        AND i.estado = 'I';
        v_valida := 'NNJJ';
      exception
       when no_data_found then
        v_cantidad := 0;
      end;
   End if;
   
   /*No encuentra, entonces va por Lóg. 6: Donde busca los 2 nombres y 1° apellido */
   IF NVL(v_cantidad, 0) = 0  AND p_nombre IS NOT NULL AND p_s_nombre IS NOT NULL  AND p_apellido IS NOT NULL THEN
     begin
      SELECT COUNT(*)
       into v_cantidad
       FROM Ba_Per_Juridicas pj, ge_per_inhibidas i
       where ((upper(pj.raz_social) like
          '%'||upper(p_nombre) ||'%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%') or 
         (upper(pj.nom_comercial) like
          '%'||upper(p_nombre) ||'%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%'))
         and pj.cod_persona = i.cod_persona
         AND i.cod_causa in (Select t.val_minimo  from ba_cod_referencias t where t.dominio = 'COD_INH_LISTAS')
         AND i.estado = 'I';
        v_valida := 'NNJ';
     exception
      when no_data_found then       
      v_cantidad := 0;
      end;
   End if;
   
   
   /*No encuentra, entonces va por Lóg. 7: Donde busca el 1°nombre y y ambos apellidos */
   IF NVL(v_cantidad, 0) = 0  AND p_nombre IS NOT NULL  AND p_apellido IS NOT NULL AND p_s_apellido IS NOT NULL  THEN
      begin
        SELECT COUNT(*)
         into v_cantidad
        FROM Ba_Per_Juridicas pj, ge_per_inhibidas i
        where ((upper(pj.raz_social) like
           '%'||upper(p_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%') or 
           (upper(pj.nom_comercial) like
            '%'||upper(p_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%'))
           and pj.cod_persona = i.cod_persona
           AND i.cod_causa in (Select t.val_minimo  from ba_cod_referencias t where t.dominio = 'COD_INH_LISTAS')
           AND i.estado = 'I';
        v_valida := 'NJJ';
      exception
       when no_data_found then
       v_cantidad := 0;
      End;
   End if;
             
   /*No encuentra, entonces va por Lóg. 8: Donde busca el segunfo nombre y 1° apellido y 2° apellido también */
   IF NVL(v_cantidad, 0) = 0  AND p_s_nombre IS NOT NULL  AND p_apellido IS NOT NULL AND p_s_apellido IS NOT NULL  THEN
       begin
        SELECT COUNT(*)
          into v_cantidad
         FROM Ba_Per_Juridicas pj, ge_per_inhibidas i
         where ((upper(pj.raz_social) like
              '%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%') or 
             (upper(pj.nom_comercial) like
              '%'||upper(p_s_nombre) ||'%'||upper(p_apellido) ||'%'|| upper(p_s_apellido) ||'%'))
          and pj.cod_persona = i.cod_persona
          AND i.cod_causa in (Select t.val_minimo  from ba_cod_referencias t where t.dominio = 'COD_INH_LISTAS')
          AND i.estado = 'I';
          v_valida := 'NJ';
        exception
        when no_data_found then
        v_cantidad := 0;
        end;
  END IF;
  
   /* IF NVL(v_cantidad, 0) = 0 THEN
    -- Si carga solo el Segundo nombre y el Segundo apellido
     SELECT COUNT(*)
      into v_cantidad
      FROM Ba_Per_Juridicas pj, ge_per_inhibidas i
     where ((replace(pj.raz_social, ' ', '') like
           '%'||upper(p_nombre) ||'%'|| upper(p_apellido) ||'%') or 
           (replace(pj.nom_comercial, ' ', '') like
           '%'||upper(p_nombre) ||'%'|| upper(p_apellido) ||'%'))
       and pj.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';
    v_valida := 'NNJJ';
  END IF; Comentado DA-7081*/

  IF V_CANTIDAD > 0 THEN
    IF v_valida = 'NNAA' or v_valida = 'NNJJ' then   
      p_cod_mensaje := '001';
      p_mensaje     := 'Existe persona con el nombre completo exactamente igual dentro de las Listas. Verifique';
    ELSE
      if v_valida = 'NNA' OR v_valida = 'NAA' OR v_valida = 'NA' OR v_valida = 'NJJ' OR v_valida = 'NNJ' OR v_valida = 'NJ'   Then
        p_cod_mensaje := '001';
        p_mensaje     := 'Existe persona con el nombre parecido en las Listas. Verifique';
      end if;
    END IF;
  END IF;
END;
/

