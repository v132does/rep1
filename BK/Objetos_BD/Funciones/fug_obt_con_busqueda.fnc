CREATE OR REPLACE FUNCTION IT.fug_obt_con_busqueda(p_condicion IN VARCHAR2) RETURN VARCHAR2 IS
   /*
   | Función que retorna la condición de busqueda para utilizar en la función CATSEARCH
   */
   v_condicion VARCHAR2(1000) := p_condicion;

   FUNCTION lf_rep_car_reservadas(p_valor IN VARCHAR2) RETURN VARCHAR2 IS
      v_valor VARCHAR2(1000) := p_valor;
   BEGIN
      -- elimina los caracteres especiales
      v_valor := translate(v_valor, '&|"()', '*');
      v_valor := REPLACE(v_valor, '*', '');
      v_valor := REPLACE(v_valor, '"', '');
      v_valor := REPLACE(v_valor, '(', '');
      v_valor := REPLACE(v_valor, ')', '');

      v_valor := REPLACE(v_valor, ' -', ' ');
      v_valor := REPLACE(v_valor, '- ', ' ');
      v_valor := REPLACE(v_valor, ' AND ', ' ');
      v_valor := REPLACE(v_valor, ' OR ', ' ');
      v_valor := REPLACE(v_valor, ' NOT ', ' ');

      RETURN v_valor;
   END;

BEGIN
   v_condicion := lf_rep_car_reservadas(v_condicion);

   IF substr(v_condicion, 1, 1) = '%' THEN
      v_condicion := substr(v_condicion, 2);
   END IF;

   v_condicion := REPLACE(v_condicion, '%', '* ');
   v_condicion := REPLACE(v_condicion, '_', '*');
   v_condicion := ltrim(rtrim(v_condicion));

   RETURN v_condicion;
END;
/

