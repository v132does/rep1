CREATE OR REPLACE FUNCTION IT.fuw_obt_des_grupo(p_cod_grupo IN wf_grupos.cod_grupo%TYPE)
   RETURN VARCHAR2 IS

   v_descripcion wf_grupos.descripcion%TYPE;
BEGIN
   --Obtiene el Codigo del grupo al cual pertenece el usuario
   SELECT descripcion
     INTO v_descripcion
     FROM wf_grupos
    WHERE cod_grupo = p_cod_grupo;

   RETURN v_descripcion;

EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

