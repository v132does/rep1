create or replace function it.FUG_TRAE_SUBMOTIVO_REC(P_COD_MOTIVO IN NUMBER, P_SUBMOTIVO  IN VARCHAR2) return varchar2 is
  v_longitud NUMBER(2);
  v_cod_sub_motivo NUMBER(1);
  v_desc_sub_motivo VARCHAR2(500);
  v_descripcion VARCHAR2(50); 
begin
--------
    v_longitud := length(P_SUBMOTIVO);  
    v_desc_sub_motivo := '';  
    IF v_longitud > 0 THEN
      FOR i in 1..v_longitud LOOP
        v_cod_sub_motivo := substr(P_SUBMOTIVO, i, 1);
        BEGIN
            SELECT '('||R.VAL_MAXIMO||') ' || R.SIGNIFICADO 
            into   v_descripcion
            FROM   ba_cod_referencias R
            WHERE  R.DOMINIO     = 'SUB_MOT_RECHAZO_CHEQUE'
            AND    R.VAL_MAXIMO  = v_cod_sub_motivo
            AND    R.VAL_MINIMO  = (NVL(fug_obt_parcausales(P_COD_MOTIVO,'COD_DEV_BCP'),'01'))||'_'||v_cod_sub_motivo;
        EXCEPTION
           WHEN OTHERS THEN
             v_descripcion := null;   
        END;  
        v_desc_sub_motivo := v_desc_sub_motivo||' '||NVL(v_descripcion,'');
      
      END LOOP;
   ELSE
      v_desc_sub_motivo := NULL;  
   END IF;
   RETURN  v_desc_sub_motivo;
end FUG_TRAE_SUBMOTIVO_REC;
/

