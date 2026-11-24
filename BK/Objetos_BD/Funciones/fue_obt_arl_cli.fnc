CREATE OR REPLACE FUNCTION IT.FUE_OBT_ARL_CLI(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
   RETURN STRING  

 IS
   V_PUNTAJE       varchar2(20);
   v_cod_pais      varchar2(20);
   v_tip_documento varchar2(50);
   v_nro_documento varchar2(200);
Begin
   begin
      select pai_psa.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento, p.COD_PAIS), 'BA_PAISES'),
             pai_psa.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS'),
             p.nro_documento
        into v_cod_pais, v_tip_documento, v_nro_documento
        from ba_personas p
       where p.cod_persona = P_COD_PERSONA;
   exception
      when no_data_found then
         return /*v_puntaje :=*/ 'N/A';
   end;

   begin
      select lpad(ltrim(rtrim(T.PSA044_HISpun)) || '-' || ltrim(rtrim(t.PSA044_HISdpu))/* || '=' || ltrim(rtrim(T.PSA044_HISc01))*/,20)
        INTO V_PUNTAJE
        from PSA044_HIS t
       where t.PSA044_HISpai = v_cod_pais
         AND T.PSA044_HISTDO = v_tip_documento
         AND LTRIM(RTRIM(T.PSA044_HISNDO)) = v_nro_documento
         AND TO_DATE(t.PSA044_HISFFI, 'RRRRMMDD') =
             (select max(TO_DATE(b.PSA044_HISFFI, 'RRRRMMDD'))
                from PSA044_HIS B
               where B.PSA044_HISpai = v_cod_pais
                 AND B.PSA044_HISTDO = v_tip_documento
                 AND LTRIM(RTRIM(B.PSA044_HISNDO)) = v_nro_documento)
         AND ROWNUM = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         V_PUNTAJE := 'SIN RESULTADO';
   end;

   return V_PUNTAJE;
End;
/

