create or replace procedure it.PRG_PER_ONB_INHIBIDAS(p_nombre      in varchar2,
                                                     p_documento   in varchar2,                                                     
                                                     p_apellido    in varchar2,                                                      
                                                     p_cod_mensaje out varchar2,
                                                     p_mensaje     out varchar2) IS

  v_cant_documento NUMBER(10) := 0;
  v_cant_nombre NUMBER(10) := 0; 

BEGIN
  p_cod_mensaje := '0';
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  /*Verifica por numero de documento*/
  IF p_documento IS NOT NULL THEN
     SELECT COUNT(*)
      into v_cant_documento
      FROM BA_PER_FISICAS pf,ba_personas ba, ge_per_inhibidas i
     WHERE ba.nro_documento=p_documento
       AND pf.cod_persona=ba.cod_persona
       AND pf.cod_persona = i.cod_persona
       AND i.cod_causa in
           (Select t.val_minimo
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS')
       AND i.estado = 'I';      
  END IF;
  
    /*Verifica por nombre completo*/
  IF v_cant_documento = 0 THEN 
      IF upper(p_nombre) IS NOT NULL AND upper(p_apellido) IS NOT NULL  THEN
         SELECT COUNT(*)
          into v_cant_nombre
          FROM BA_PER_FISICAS pf, ge_per_inhibidas i
         WHERE pf.pri_nombre = fug_obt_nombre(p_nombre, 1)       
           AND pf.SEG_NOMBRE = fug_obt_nombre(p_nombre, 2)     
           AND pf.PRI_APELLIDO =fug_obt_nombre(p_apellido, 1)  
           AND pf.SEG_APELLIDO = fug_obt_nombre(p_apellido, 2) 
           AND pf.cod_persona = i.cod_persona
           AND i.cod_causa in
               (Select t.val_minimo
                  from ba_cod_referencias t
                 where t.dominio = 'COD_INH_LISTAS')
           AND i.estado = 'I';          
      END IF;  
  END IF;
  
  IF v_cant_documento > 0 OR v_cant_nombre > 0  THEN
      p_cod_mensaje := '001';
      p_mensaje     := 'Existe persona con el nombre completo exactamente igual dentro de las Listas';     
  END IF;
  
  
END;
/
