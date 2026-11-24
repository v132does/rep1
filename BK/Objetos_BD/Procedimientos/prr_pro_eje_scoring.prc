CREATE OR REPLACE PROCEDURE IT.PRR_PRO_EJE_SCORING
 (P_CDOFCTA IN VARCHAR2 := 'null'
 ,P_CDPERSO IN VARCHAR2 := 'null'
 ,P_COD_PUNTAJE IN OUT NUMBER
 )
 IS

  v_cdgruco cr_pun_conceptos.cod_gru_concepto%type;

/* Utilizado por el procedimiento PRC_PRO_EJE_SCORING. */
PROCEDURE PR_CRE_CON_SQL
 (P_CDPERSO IN VARCHAR2
 ,P_CDSCORI IN NUMBER
 );
/* Utilizado por el procedimiento PR_CRE_CON_SQL. */
FUNCTION FU_CAM_REFERENCIA
 (P_CDCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 ,P_TIPDATO IN VARCHAR2
 )
 RETURN VARCHAR2;
/* Obtener valores de puntaje. */
PROCEDURE PR_OBT_COD_DES
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PVALUE IN OUT VARCHAR2
 ,PLABEL IN OUT VARCHAR2
 );
/* Proceso utilizado por el scoring. */
PROCEDURE PR_OBT_DES_HAST
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PTIPO IN OUT VARCHAR2
 ,PDESDE IN OUT VARCHAR2
 ,PHASTA IN OUT VARCHAR2
 );
/* Procedimiento utilizado por FU_CAM_REFERENCIA. */
PROCEDURE PR_OBT_VAL_RANGO
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PVALUE IN OUT VARCHAR2
 ,PLABEL IN OUT VARCHAR2
 ,PTIPO IN OUT VARCHAR2
 ,PDESDE IN OUT VARCHAR2
 ,PHASTA IN OUT VARCHAR2
 );

/* Utilizado por el procedimiento PRC_PRO_EJE_SCORING. */
PROCEDURE PR_CRE_CON_SQL
 (P_CDPERSO IN VARCHAR2
 ,P_CDSCORI IN NUMBER
 )
 IS

/* Procedimiento utilizado por PR_CRE_CONSULTA_SQL. */
PROCEDURE PR_PRO_SQL
 (P_CDPERSO IN VARCHAR2
 ,P_CDSCORI IN NUMBER
 ,P_SQL IN LONG
 ,P_COLUMNAS IN NUMBER
 ,P_FILAS IN OUT NUMBER
 ,P_ERROR IN OUT VARCHAR2
 );

/* Procedimiento utilizado por PR_CRE_CONSULTA_SQL. */
PROCEDURE PR_PRO_SQL
 (P_CDPERSO IN VARCHAR2
 ,P_CDSCORI IN NUMBER
 ,P_SQL IN LONG
 ,P_COLUMNAS IN NUMBER
 ,P_FILAS IN OUT NUMBER
 ,P_ERROR IN OUT VARCHAR2
 )
 IS

/* Funcion utilizada por P_PROCESA_SQL. */
FUNCTION FU_OBT_PUNTAJE
 (P_CDSCORI IN NUMBER
 ,P_CDCAMPO IN VARCHAR2
 ,P_VALOR VARCHAR2
 ,P_PONDERA IN OUT VARCHAR2
 )
 RETURN NUMBER;

/* Funcion utilizada por P_PROCESA_SQL. */
FUNCTION FU_OBT_PUNTAJE
 (P_CDSCORI IN NUMBER
 ,P_CDCAMPO IN VARCHAR2
 ,P_VALOR VARCHAR2
 ,P_PONDERA IN OUT VARCHAR2
 )
 RETURN NUMBER
 IS

/* Funcion utilizada por FU_OBT_PUNTAJE */
FUNCTION FU_PRO_CAM_MUL
 (P_CDCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2;
/* Funcion utilizada por FU_OBT_PUNTAJE. */
FUNCTION FU_PRO_CAM_RAN
 (P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2;
/* Funcion utilizada por  FU_OBT_PUNTAJE */
FUNCTION FU_PRO_CAM_VAL
 (P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 )
 RETURN VARCHAR2;
type           T_array is table of varchar2(120) index by binary_integer;
  reg            t_array;

  v_puntaje number(10);
  v_detasql long;
  v_nmrefer varchar2(2000);
  v_valotro CR_PUN_CONCEPTOS.VAL_OTRO%type;
  v_col_varchar2 varchar2(120);
  v_result       boolean;
  v_cursor       number;
  v_rows         number(10) := 0;
  Cursor c1 is
            Select s.DESCRIPCION, s.PUNTAJE, p.TIP_DATO, p.TIP_CAMPO, p.NOM_REFERENCIA,
                   c.VAL_NULO, c.VAL_OTRO, c.PONDERACION, c.cod_gru_concepto
              from GE_FILTROS p, CR_PUN_VALORES s, CR_PUN_CONCEPTOS c
             where p.COD_CAMPO = s.COD_CAMPO
               and s.COD_PUNTAJE = c.COD_PUNTAJE
               and s.COD_CAMPO = c.COD_CAMPO
               and c.COD_PUNTAJE = p_cdscori
               and c.COD_CAMPO = p_cdcampo; 

/* Funcion utilizada por FU_OBT_PUNTAJE */
FUNCTION FU_PRO_CAM_MUL
 (P_CDCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
vString VarChar2(300) := p_dcvalor;
  vLength Number(10)    := nvl(Length(vString),0);
  vPosicion Number(10)  := 1;
  vCountReg Number(10)  := 1;
  vLabel VarChar2(100);
  vDesde VarChar2(100);
  vHasta VarChar2(100);
  vTipo VarChar2(100);
  vValue VarChar2(5);
  v_retorno varchar2(400) := null;
  v_or varchar2(02) := null;
Begin
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    vDesde := Null;
    vHasta := Null;
    vTipo := Null;
    -- obtengo los datos de la cadena recibida ---------------------------------------
    PR_OBT_VAL_RANGO ( vString,vPosicion,vValue,vLabel,vTipo,vDesde,vHasta );
    if    vtipo = 'Mayor_a' then
    	    vtipo := '>';
    elsif vtipo = 'Menor_a' then
    	    vtipo := '<';
    elsif vtipo = 'Mayor_o_Igual_a' then
    	    vtipo := '>=';
    elsif vtipo = 'Menor_o_Igual_a' then
    	    vtipo := '<=';
    elsif vtipo = 'Igual_a' then
    	    vtipo := '=';
    elsif vtipo = 'Entre' then
    	    vtipo := 'Between';
    End if;
    if p_tpcampo = 'S' then -- tipo alfabetico
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' '||vtipo||' '||chr(39) ||vDesde || chr(39);
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and '||chr(39) ||vhasta || chr(39);
    	 end if;
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' '||vtipo||' '||vDesde;
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and ' || vhasta;
    	 end if;
    elsif p_tpcampo = 'F' then -- tipo fecha
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' '||vtipo||' to_date('||vDesde||')';
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and to_date(' || vhasta ||')';
    	 end if;
    end if;
    v_or := 'OR';
  End Loop;
  return v_retorno;
End;
/* Funcion utilizada por FU_OBT_PUNTAJE. */
FUNCTION FU_PRO_CAM_RAN
 (P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
vString VarChar2(300):= p_dcvalor;
  vLength Number(10)   := nvl(Length(vString),0);
  vPosicion Number(10) := 1;
  vDesde VarChar2(100);
  vHasta VarChar2(100);
  vTipo VarChar2(100);
  v_retorno varchar2(300);
  v_or varchar2(2) := null;
Begin
  Loop
    Exit When vPosicion >= vLength;
    vTipo := Null;
    vDesde := Null;
    vHasta := Null;
    -- Obtengo el valor desde y hasta de la cadena recibida ---------
    PR_OBT_DES_HAST (vString,vPosicion,vTipo,vDesde,vHasta );
    if    vtipo = 'Mayor_a' then
    	    vtipo := '>';
    elsif vtipo = 'Menor_a' then
    	    vtipo := '<';
    elsif vtipo = 'Mayor_o_Igual_a' then
    	    vtipo := '>=';
    elsif vtipo = 'Menor_o_Igual_a' then
    	    vtipo := '<=';
    elsif vtipo = 'Igual_a' then
    	    vtipo := '=';
    elsif vtipo = 'Entre' then
    	    vtipo := 'Between';
    End if;
    if p_tpcampo = 'S' then -- tipo alfabetico
    	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' '||chr(39) ||vDesde || chr(39);
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and '||chr(39) ||vhasta || chr(39);
    	 end if;
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' '||vDesde;
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and ' || vhasta;
    	 end if;
    elsif p_tpcampo = 'F' then -- tipo fecha
     	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' to_date('||vDesde||')';
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and to_date(' || vhasta ||')';
    	 end if;
    end if;
    v_or := 'OR';
  End Loop;
  return v_retorno;
End;
/* Funcion utilizada por  FU_OBT_PUNTAJE */
FUNCTION FU_PRO_CAM_VAL
 (P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
vString VarChar2(300) := p_dcvalor;
  vLength Number(10) := nvl(Length(vString),0);
  vPosicion Number(10) := 1;
  vValue VarChar2(100);
  vLabel VarChar2(100);
  v_retorno varchar2(400) := p_nmrefer||' IN (';
  v_or varchar2(02) := null;
Begin
if instr(p_nmrefer,'&CODIGO') > 0 then
	v_retorno := null;
  IF instr(p_dcvalor,chr(243)) > 0 then -- existe una relacion or
     v_retorno := ' (';
  end if;
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    -- Obtengo el codigo y descripcion del valor en la cadena  -------
    PR_OBT_COD_DES (vString,vPosicion,vValue,vLabel);
    v_retorno := v_retorno ||' '||v_or;
    v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' = '||chr(39) ||'S'|| chr(39);
    v_or := 'OR';
  End Loop;
  IF instr(p_dcvalor,chr(243)) > 0 then -- existe una relacion or
     v_retorno := v_retorno||')';
  end if;
else
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    -- Obtengo el codigo y descripcion del valor en la cadena  -------
    PR_OBT_COD_DES (vString,vPosicion,vValue,vLabel);
    if p_tpcampo = 'S' then -- tipo alfabetico
    	 v_retorno := v_retorno || chr(39) ||vValue || chr(39) || ',';
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno || vValue || ',';
    elsif p_tpcampo = 'F' then -- tipo fecha
    	 v_retorno := v_retorno || 'to_date('||vValue||'),';
    end if;
  End Loop;
  v_retorno := substr(v_retorno,1,length(v_retorno)-1)||')';
end if;
return v_retorno;
End;
BEGIN
	For r1 in c1 LOOP
		 v_nmrefer := r1.NOM_REFERENCIA;
		 v_valotro := r1.VAL_OTRO;
		 p_pondera := r1.PONDERACION;
     v_cdgruco := r1.cod_gru_concepto;
		 If p_valor is null Then
		 	  v_puntaje := r1.VAL_NULO;
		 	  exit;
		 Else
		 if instr(r1.NOM_REFERENCIA,'&CODIGO') > 0 then
      	 v_nmrefer := fu_cam_referencia(p_cdcampo,r1.NOM_REFERENCIA,r1.DESCRIPCION,r1.TIP_CAMPO,r1.TIP_DATO);
     end if;
  	 IF p_cdcampo IS NOT NULL AND r1.DESCRIPCION IS NOT NULL THEN
  	 	  v_detasql := 'Select '||r1.PUNTAJE|| chr(10)||' from dual '||chr(10)||'where ';
  	 	  -- Filtro valido, proceso el mismo ------------------------------------
  	 	  if r1.TIP_DATO = 'V' then -- tipo valor
  	 	  	  v_detasql := v_detasql||' '||FU_PRO_CAM_VAL(r1.DESCRIPCION,r1.TIP_CAMPO,v_nmrefer);
  	 	  elsif r1.TIP_DATO = 'R' then -- tipo rango
  	 	  	  IF instr(r1.DESCRIPCION,chr(243)) > 0 then -- existe una relacion or
  	 	  	  	 v_detasql := v_detasql||' (';
  	 	  	  end if;
  	 	  	  v_detasql := v_detasql||' '||FU_PRO_CAM_RAN(v_nmrefer,r1.DESCRIPCION,r1.TIP_CAMPO);
  	 	  	  IF instr(r1.DESCRIPCION,chr(243)) > 0 then -- existe una relacion or
  	 	  	  	 v_detasql := v_detasql||')';
  	 	  	  end if;
  	 	  elsif r1.TIP_DATO = 'M' then -- tipo multiple
  	 	  	  IF instr(r1.DESCRIPCION,chr(243)) > 0 then -- existe una relacion or
  	 	  	  	 v_detasql := v_detasql||' (';
  	 	  	  end if;
  	 	  	  v_detasql := v_detasql||' '||FU_PRO_CAM_MUL(p_cdcampo,v_nmrefer,r1.DESCRIPCION,r1.TIP_CAMPO);
  	 	  	  IF instr(r1.DESCRIPCION,chr(243)) > 0 then -- existe una relacion or
  	 	  	  	 v_detasql := v_detasql||')';
  	 	  	  end if;
  	 	  end if;
  	 	  If r1.TIP_CAMPO = 'S' Then -- Alfabetico
  	 	     v_detasql := replace(v_detasql, v_nmrefer, chr(39)||p_valor||chr(39));
  	 	  Elsif r1.TIP_CAMPO = 'N' Then -- Numerico
  	 	  	 v_detasql := replace(v_detasql, v_nmrefer, p_valor);
  	 	  Elsif r1.TIP_CAMPO = 'F' Then
  	 	  	 v_detasql := replace(v_detasql, v_nmrefer, 'to_date('||chr(39)||p_valor||chr(39)||')');
  	 	  End If;
  	 	  -------------------------------------------------------------------
       	--- Obtiene el puntaje de acuerdo al select que armó mas arriba ---
  	 	  -------------------------------------------------------------------
		       v_cursor := dbms_sql.open_cursor;
		       v_result := dbms_sql.is_open(v_cursor);
		       if v_result then
			        dbms_sql.parse(v_cursor,v_detasql,1); --1 = dbms_sql.native NATIVE, 2 = V7 Y 0 = V6
			        -- Variables en el cursors
	            dbms_sql.define_column(v_cursor,1,v_col_varchar2,200);
			        v_rows := dbms_sql.execute(v_cursor);
			     end if;
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
        If v_rows != 0 Then
   		     dbms_sql.column_value(v_cursor,1,reg(1));
   		     v_puntaje := reg(1);
   		     dbms_sql.close_cursor(v_cursor);
   		     exit; 
        End If;
        dbms_sql.close_cursor(v_cursor);
        --- Hasta aqui es la ejecución --
  	 	  -------------------------------------------------------------------
  	 END IF;
  	 End If;
	END LOOP;
  If v_puntaje is null and p_valor is not null Then -- Asigna otro valor --
  	 v_puntaje := v_valotro;
  End If;
	Return v_puntaje;
END;
BEGIN
DECLARE
    ---
    type           T_array is table of varchar2(120) index by binary_integer;
    reg            t_array;
    nom            t_array;
    v_col_varchar2 varchar2(120);
    v_result       boolean;
    v_cursor       number;
    v_rows         number(10) := 1;
    v_cont         number(5) := 1;
    v_puntaje      number(5);
    v_pun_tot      number(5);
    v_pondera	     CR_PUN_CONCEPTOS.PONDERACION%type;
Begin
    p_error := null;
    p_filas := 0;
    v_pun_tot := 0;
    --- Borro los puntajes anteriores ---
    Delete from CR_PUN_PERSONAS
     where COD_PERSONA = p_cdperso
       and COD_PUNTAJE = p_cdscori;
    Delete from CR_PER_PUNTAJES
     where COD_PERSONA = p_cdperso
       and COD_PUNTAJE = p_cdscori;
    ---
    if p_sql is not null and p_columnas > 0 then
		  v_result := dbms_sql.is_open(v_cursor);
		  if not v_result then
		    v_cursor := dbms_sql.open_cursor;
		    v_result := dbms_sql.is_open(v_cursor);
		    if v_result then
			    dbms_sql.parse(v_cursor,p_sql,1); --1 = dbms_sql.native NATIVE, 2 = V7 Y 0 = V6
			    --Variables en el cursors
          for i in 1..p_columnas loop
			      dbms_sql.define_column(v_cursor,i,v_col_varchar2,200);
          end loop;
			    v_rows := dbms_sql.execute(v_cursor);
			  end if;
		  end if;
      v_rows :=  dbms_sql.fetch_rows(v_cursor);
      loop exit when v_rows = 0;
 	      p_filas := p_filas + 1;
        for i in 1..p_columnas loop
        	If i/2 != trunc(i/2) Then
     		     dbms_sql.column_value(v_cursor,i,reg(i));
        	Else
        		 dbms_sql.column_value(v_cursor,i,nom(i));
        		 v_puntaje := FU_OBT_PUNTAJE(p_cdscori, nom(i), reg(i-1), v_pondera);
        		 v_pun_tot := nvl(v_pun_tot,0) + nvl((nvl(v_puntaje,0) * nvl(v_pondera,1) / 100),0);
             insert into CR_PUN_PERSONAS
                (COD_PERSONA, COD_PUNTAJE, COD_CAMPO, VAL_CAMPO, PUNTAJE, COD_GRU_CONCEPTO)
             values
                (p_cdperso, p_cdscori, nom(i), reg(i-1), v_puntaje, v_cdgruco);
     		  End If;
        end loop;
    	  v_rows :=  dbms_sql.fetch_rows(v_cursor);
      end loop;
  	  dbms_sql.close_cursor(v_cursor);
    end if;
    ---
    Insert into CR_PER_PUNTAJES
    (COD_PERSONA, COD_PUNTAJE, PUNTAJE)
    Values
    (p_cdperso, p_cdscori, v_pun_tot);
    ---
    Commit;
   exception
	   when others then
	     -- p_error := 'ORA-20000'||sqlerrm;
       raise_application_error(-20000,sqlerrm||'-'||p_sql);
END;
END;
BEGIN
  DECLARE
v_perfisi  varchar2(01) := 'N';
v_perjuri  varchar2(01) := 'N';
v_ltablas  varchar2(500) := null;
v_lcamfis  varchar2(2000) := null;
v_lcamjur  varchar2(2000) := null;
v_nmwhere  varchar2(500) := null;
v_nmrefer  varchar2(2000);
v_sql      long;
v_columnas number(5) := 0;
v_filas    number(5) := 0;
v_error    varchar2(200);
  Cursor c1 is
            Select c.COD_PUNTAJE, c.COD_CAMPO, c.VAL_NULO, c.VAL_OTRO, c.PONDERACION,
                   p.TIP_CAMPO, p.LON_CAMPO, p.TIP_DATO, p.VAL_MAX_PERMITIDO, p.VAL_MIN_PERMITIDO,
                   p.DET_SQL, p.NOM_TAB_ASOCIADA, p.NOM_REFERENCIA, p.NRO_ORDEN, c.cod_gru_concepto,
                   min(s.DESCRIPCION) DESCRIPCION, min(s.PUNTAJE) PUNTAJE
              from GE_FILTROS p, CR_PUN_VALORES s, CR_PUN_CONCEPTOS c
             where p.COD_CAMPO = c.COD_CAMPO
               and p.COD_CAMPO = s.COD_CAMPO
               and s.COD_PUNTAJE = c.COD_PUNTAJE
               and s.COD_CAMPO = c.COD_CAMPO
               and c.COD_PUNTAJE = p_cdscori   
               Group by c.COD_PUNTAJE, c.COD_CAMPO, c.VAL_NULO, c.VAL_OTRO, c.PONDERACION,
                   p.TIP_CAMPO, p.LON_CAMPO, p.TIP_DATO, p.VAL_MAX_PERMITIDO, p.VAL_MIN_PERMITIDO,
                   p.DET_SQL, p.NOM_TAB_ASOCIADA, p.NOM_REFERENCIA, p.NRO_ORDEN, c.cod_gru_concepto;
BEGIN
  -- Recorro una vez para tomar las tablas incluidas y el tipo de persona -----
  For r1 in c1 LOOP
     v_cdgruco := r1.cod_gru_concepto;
  	 IF r1.COD_CAMPO IS NOT NULL  THEN
  	 	  v_columnas := v_columnas + 2;
  	 	  -- Tomo solo si con filtros validos -----------------------------------
        IF    r1.NOM_TAB_ASOCIADA = 'BA_PER_FISICAS' THEN
        	  v_perfisi := 'S';
        ELSIF r1.NOM_TAB_ASOCIADA = 'BA_PER_JURIDICAS' THEN
        	  v_perjuri := 'S';
        ELSIF r1.NOM_TAB_ASOCIADA = 'BA_PERSONAS' THEN
        	  v_perfisi := 'S';
        	  v_perjuri := 'S';
        	  IF r1.COD_CAMPO = 'TIP_PERSONA' THEN
        	  	 IF INSTR(r1.DESCRIPCION,'F-') > 0 THEN
        	  	 	  v_perfisi := 'S';
        	  	 END IF;
        	  	 IF INSTR(r1.DESCRIPCION,'J-') > 0 THEN
        	  	 	  v_perjuri := 'S';
        	  	 END IF;
        	  END IF;
        ELSE
        	  IF INSTR(nvl(v_ltablas,' '),r1.NOM_TAB_ASOCIADA) = 0 then
        	  	 -- agrego a lista de tablas ------------------------------------
        	  	 IF r1.NOM_TAB_ASOCIADA = 'GE_CLIENTES' then
        	  	 	  v_ltablas := v_ltablas ||r1.NOM_TAB_ASOCIADA||' C,';
        	  	 	  v_nmwhere := v_nmwhere || '   and C.COD_PERSONA = P.COD_PERSONA';
        	  	 ELSE
        	  	 	  v_ltablas := v_ltablas ||r1.NOM_TAB_ASOCIADA||',';
        	  	 END IF;
        	  END IF;
        END IF;
        IF r1.NOM_TAB_ASOCIADA = 'BA_PER_JURIDICAS' THEN
        	  IF    r1.TIP_CAMPO = 'S' THEN
        	  	  v_lcamfis := v_lcamfis ||', NULL, '''||r1.COD_CAMPO||'''';
        	  ELSIF r1.TIP_CAMPO = 'F' THEN
        	  	  v_lcamfis := v_lcamfis ||', TO_DATE(NULL), '''||r1.COD_CAMPO||'''';
        	  ELSIF r1.TIP_CAMPO = 'N' THEN
        	  	  v_lcamfis := v_lcamfis ||', TO_NUMBER(NULL), '''||r1.COD_CAMPO||'''';
        	  END IF;
        	  v_nmrefer := r1.NOM_REFERENCIA;
        	  if instr(r1.NOM_REFERENCIA,'&CODIGO') > 0 then
        	  	 v_nmrefer := FU_CAM_REFERENCIA(r1.COD_CAMPO,r1.NOM_REFERENCIA,r1.DESCRIPCION,r1.TIP_CAMPO,r1.TIP_DATO);
        	  end if;
            v_lcamjur := v_lcamjur ||', '||v_nmrefer||', '''||r1.COD_CAMPO||'''';
        ELSIF r1.NOM_TAB_ASOCIADA = 'BA_PER_FISICAS' THEN
        	  IF    r1.TIP_CAMPO = 'S' THEN
        	  	  v_lcamjur := v_lcamjur ||', NULL, '''||r1.COD_CAMPO||'''';
        	  ELSIF r1.TIP_CAMPO = 'F' THEN
        	  	  v_lcamjur := v_lcamjur ||', TO_DATE(NULL), '''||r1.COD_CAMPO||'''';
        	  ELSIF r1.TIP_CAMPO = 'N' THEN
        	  	  v_lcamjur := v_lcamjur ||', TO_NUMBER(NULL), '''||r1.COD_CAMPO||'''';
        	  END IF;
        	  v_nmrefer := r1.NOM_REFERENCIA;
        	  if instr(r1.NOM_REFERENCIA,'&CODIGO') > 0 then
        	  	 v_nmrefer := FU_CAM_REFERENCIA(r1.COD_CAMPO,r1.NOM_REFERENCIA,r1.DESCRIPCION,r1.TIP_CAMPO,r1.TIP_DATO);
        	  end if;
            v_lcamfis := v_lcamfis ||', '||v_nmrefer||', '''||r1.COD_CAMPO||'''';
        ELSE
        	  v_nmrefer := r1.NOM_REFERENCIA;
        	  if instr(r1.NOM_REFERENCIA,'&CODIGO') > 0 then
        	  	 v_nmrefer := FU_CAM_REFERENCIA(r1.COD_CAMPO,r1.NOM_REFERENCIA,r1.DESCRIPCION,r1.TIP_CAMPO,r1.TIP_DATO);
        	  end if;
            v_lcamfis := v_lcamfis ||', '||v_nmrefer||', '''||r1.COD_CAMPO||'''';
            v_lcamjur := v_lcamjur ||', '||v_nmrefer||', '''||r1.COD_CAMPO||'''';
        END IF;
  	 END IF;
  END LOOP;
  IF v_perfisi = 'N' and v_perjuri = 'N' then
  	 v_perfisi := 'S';
  	 v_perjuri := 'S';
  END IF;
  IF v_perfisi = 'S' THEN -- tiene filtros para personas fisicas -------------
  -- Inicializo la variable de sql
   v_sql := 'Select '||substr(v_lcamfis, 3) ||chr(10)||
            '  from '||v_ltablas||'BA_PER_FISICAS f, BA_PERSONAS p'||chr(10)||
            ' where f.COD_PERSONA = p.COD_PERSONA and p.COD_PERSONA = '''||p_cdperso||'''';
  IF v_nmwhere is not null then
  	 v_sql := v_sql ||chr(10)||v_nmwhere;
  END IF;
END IF;

IF v_perjuri = 'S' THEN -- tiene filtros para personas juridicas -------------
  -- Inicializo la variable de sql
  IF v_perfisi ='S' THEN
  	 v_sql := v_sql || CHR(10)||' UNION '||CHR(10);
  ELSE
  	 v_sql := NULL;
  END IF;
  v_sql := v_sql||
                 'Select '||substr(v_lcamjur, 3)||chr(10)||
                 '  from '||v_ltablas||'BA_PER_JURIDICAS j,BA_PERSONAS p'||chr(10)||
                 ' where j.COD_PERSONA = p.COD_PERSONA and p.COD_PERSONA = '''||p_cdperso||'''';
  IF v_nmwhere is not null then
  	 v_sql := v_sql ||chr(10)||v_nmwhere;
  END IF;
END IF;
--p_mensaje('sql: '||v_sql);
--- Procesa el sql que genero para poder asignar los puntajes de acuerdo al valor...
PR_PRO_SQL(p_cdperso, p_cdscori, v_sql, v_columnas, v_filas, v_error);
--- Pro item.
End;
END;
/* Utilizado por el procedimiento PR_CRE_CON_SQL. */
FUNCTION FU_CAM_REFERENCIA
 (P_CDCAMPO IN VARCHAR2
 ,P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 ,P_TIPDATO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
vString VarChar2(300) := p_dcvalor;
  vLength Number(10)    := nvl(Length(vString),0);
  vPosicion Number(10)  := 1;
  vCountReg Number(10)  := 1;
  vLabel VarChar2(100);
  vDesde VarChar2(100);
  vHasta VarChar2(100);
  vTipo VarChar2(100);
  vValue VarChar2(5);
  v_retorno varchar2(400) := null;
  v_or varchar2(02) := null;
Begin
	  -- se hace una sola vez ----------------------------------------------------------
    vValue := Null;
    vLabel := Null;
    vDesde := Null;
    vHasta := Null;
    vTipo := Null;
    -- obtengo los datos de la cadena recibida ---------------------------------------
    if p_tipdato = 'M' then
       PR_OBT_VAL_RANGO ( vString,vPosicion,vValue,vLabel,vTipo,vDesde,vHasta );
    elsif p_tipdato = 'V' then
       PR_OBT_COD_DES (vString,vPosicion,vValue,vLabel);
    elsif p_tipdato = 'R' then
    	 PR_OBT_DES_HAST (vString,vPosicion,vTipo,vDesde,vHasta );
    end if;
    v_retorno := replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39));
    return v_retorno;
 End;
/* Obtener valores de puntaje. */
PROCEDURE PR_OBT_COD_DES
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PVALUE IN OUT VARCHAR2
 ,PLABEL IN OUT VARCHAR2
 )
 IS
begin
declare
  vLength Number(10) := Length(pString);
  vCaracter VarChar2(1);
  vPos1 Number(10);
  vPos2 Number(10);
Begin
  vPos1 := Instr(pString,'-',pPosicion);
  pValue := Substr(pString,pPosicion,vPos1-pPosicion);
  vPos2 := Instr(pString,CHR(243),pPosicion) - 1;
  If vPos2 > 0  Then
    pLabel := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1-1)));
    pPosicion := vPos2+3;
  Else
    pLabel := LTrim(RTrim(Substr(pString,vPos1+1,(vLength+1)-vPos1-1)));
    pPosicion := vLength+1;
  End If;
  plabel := nvl(plabel,' ');
End;
End;
/* Proceso utilizado por el scoring. */
PROCEDURE PR_OBT_DES_HAST
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PTIPO IN OUT VARCHAR2
 ,PDESDE IN OUT VARCHAR2
 ,PHASTA IN OUT VARCHAR2
 )
 IS
begin
declare
  vLength Number(10) := Length(pString);
  vCaracter VarChar2(1);
  vPos1 Number(10);
  vPos2 Number(10);
  vPos3 Number(10);
 Begin
  vPos1 := Instr(pString,' ',pPosicion);
  pTipo := LTrim(RTrim(Substr(pString,pPosicion,vPos1-pPosicion)));
  vPos2 := Instr(pString,' ',vPos1+1);
  If vPos2 = 0 Then
    pDesde := LTrim(RTrim(Substr(pString,vPos1+1)));
    pPosicion := vLength+1;
  Else
    pDesde := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1)));
    If pTipo = 'Entre' Then
      vPos3 := Instr(pString,CHR(243),vPos2);
      If vPos3 = 0 Then
        pHasta := LTrim(RTrim(Substr(pString,vPos2+3)));
        pPosicion := vLength+1;
      Else
        pHasta := LTrim(RTrim(Substr(pString,vPos2+3,vPos3-(vPos2+4))));
        pPosicion := vPos3+2;
      End If;
    Else
      pPosicion := vPos2+3;
    End If;
  End If;
 End;
end;
/* Procedimiento utilizado por FU_CAM_REFERENCIA. */
PROCEDURE PR_OBT_VAL_RANGO
 (PSTRING IN VARCHAR2
 ,PPOSICION IN OUT NUMBER
 ,PVALUE IN OUT VARCHAR2
 ,PLABEL IN OUT VARCHAR2
 ,PTIPO IN OUT VARCHAR2
 ,PDESDE IN OUT VARCHAR2
 ,PHASTA IN OUT VARCHAR2
 )
 IS
begin
declare
  vLength Number(10) := Length(pString);
  vCaracter VarChar2(1);
  vPos1 Number(10);
  vPos2 Number(10);
  vPos3 Number(10);
  vPos4 Number(10);
  vPos5 Number(10);
Begin
  vPos1  := Instr(pString,'-',pPosicion);
  pValue := Substr(pString,pPosicion,vPos1-pPosicion);
  vPos2  := Instr(pString,' ',pPosicion);
  pLabel := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1-1)));
  vPos3 := Instr(pString,' ',vpos2+1);
  pTipo := LTrim(RTrim(Substr(pString,vPos2+1,vPos3-(vPos2+1))));
  vPos4 := Instr(pString,' ',vPos3+1);
  If vPos4 = 0  Then
    pDesde := LTrim(RTrim(Substr(pString,vPos3+1)));
    pPosicion := vLength+1;
  Else
    pDesde := LTrim(RTrim(Substr(pString,vPos3+1,vPos4-(vPos3+1))));
    If pTipo = 'Entre' Then
      vPos5 := Instr(pString,CHR(243),vPos4);
      If vPos5 = 0 Then
        pHasta := LTrim(RTrim(Substr(pString,vPos4+3)));
        pPosicion := vLength+1;
      Else
        pHasta := LTrim(RTrim(Substr(pString,vPos4+3,vPos5-(vPos4+4))));
        pPosicion := vPos5+2;
      End If;
    Else
      pPosicion := vPos4+3;
    End If;
  End If;
end;
End;
BEGIN
DECLARE
  v_cdperso number(6);
-- V_MENSAJE  VARCHAR2(60);
  Cursor c1 is Select B.COD_PERSONA
                 from CR_PUNTAJES A,
           ge_solicitudes B,  ge_sol_puntajes c
    where B.cod_modulo=c.cod_modulo
            and     B.cod_modalidad=c.cod_modalidad
            and     B.cod_campana=c.cod_campana
            and     B.cod_canal=c.cod_canal
            and     A.cod_puntaje=c.cod_puntaje
            and     B.COD_USU_OFICIAL = P_cdofcta;

  Cursor c2 is Select B.COD_PERSONA
                 from CR_PUNTAJES A,
           ge_solicitudes B,  ge_sol_puntajes c
    where B.cod_modulo=c.cod_modulo
            and     B.cod_modalidad=c.cod_modalidad
            and     B.cod_campana=c.cod_campana
            and     B.cod_canal=c.cod_canal
            and     A.cod_puntaje=c.cod_puntaje;
  BEGIN
	If p_cdperso is not null Then
		 -- Se ejecutara solo para la persona que se eligio en la pantalla
 	   PR_CRE_CON_SQL(p_cdperso, p_cod_puntaje);
	Elsif p_cdofcta is not null Then
	   -- se ejecuta para todas las personas que corresponden al oficial
	   For r1 in c1 Loop
	  	   v_cdperso := r1.COD_PERSONA;
   	 	   PR_CRE_CON_SQL(v_cdperso, p_cod_PUNTAJE);
	   End Loop;
	Else
	   For r2 in c2 Loop
	   	   -- Se ejecuta para todas las personas que tienen solicitudes pendientes
	  	   v_cdperso := r2.COD_PERSONA;
   	 	   PR_CRE_CON_SQL(v_cdperso, p_COD_PUNTAJE);
	   End Loop;
	End If;
  --
END;
 -- V_mensaje :='Proceso Concluido';
END;
/

