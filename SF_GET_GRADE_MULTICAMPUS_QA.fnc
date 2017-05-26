CREATE OR REPLACE FUNCTION SF_GET_GRADE_MULTICAMPUS (
                               i_Logged_In_Jasper_Org_ID  IN org_structure_element.jasper_orgid%TYPE
                              ,i_Admin_Id IN admin_dim.adminid%TYPE
                              ,i_School_Ids IN VARCHAR2
                               )
RETURN PRS_COLL_PGT_GLOBAL_TEMP_OBJ
IS

  /*******************************************************************************
  * FUNCTION: SF_GET_GRADE_MULTICAMPUS
  * PURPOSE:   To get GRADES for for different SCHOOLS
  * CREATED:   TCS  03/JAN/2017
  * NOTE:
  *
  * MODIFIED :
  * DATE         AUTHOR :PARTHA    DESCRIPTION
  *-------------------------------------------------------------------------------
  *
  ************************************************************************************/

PRAGMA AUTONOMOUS_TRANSACTION;

  t_PRS_PGT_GLOBAL_TEMP_OBJ  PRS_PGT_GLOBAL_TEMP_OBJ;
  t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ PRS_COLL_PGT_GLOBAL_TEMP_OBJ := PRS_COLL_PGT_GLOBAL_TEMP_OBJ();
  V_ADMINID ADMIN_DIM.ADMINID%TYPE;
  --V_REGION_ID ORG_NODE_DIM.LEVEL2_JASPER_ORGID%TYPE;
  V_SCHOOL_IDS VARCHAR2(4000);

  CURSOR C_GET_GRADE (P_ADMINID_2 ADMIN_DIM.ADMINID%TYPE,ORG_ID VARCHAR2)
  IS
  SELECT DISTINCT GRD.GRADEID,
                  GRD.GRADE_NAME,
                  GRD.GRADE_SEQ
  FROM GRADE_DIM GRD,
       GRADE_SELECTION_LOOKUP GRL
  WHERE GRD.GRADEID = GRL.GRADEID
  AND GRL.ADMINID = P_ADMINID_2
  AND GRL.JASPER_ORGID  IN  (SELECT TRIM( SUBSTR ( txt
                                                   , INSTR (txt, ',', 1, level ) + 1
                                                   , INSTR (txt, ',', 1, level+1
                                                   )
                                             - INSTR (txt, ',', 1, level) -1 ) ) AS u
                                      FROM ( SELECT ','||ORG_ID||',' AS txt
                                                FROM dual )
                                       CONNECT BY level <=
                                                    LENGTH(txt)-LENGTH(REPLACE(txt,',',''))-1  )
  
  ORDER BY GRD.GRADE_SEQ;
  
  
  /*CURSOR C_SCHOOL (P_ADMINID_1 ADMIN_DIM.ADMINID%TYPE, V_REGIONID ORG_NODE_DIM.LEVEL2_JASPER_ORGID%TYPE)
  IS
  SELECT DISTINCT O.LEVEL3_JASPER_ORGID AS ORG_NODEID,
                  O.LEVEL3_ELEMENT_NAME AS ORG_NODE_NAME
             FROM ORG_NODE_DIM O
             WHERE O.LEVEL2_JASPER_ORGID = V_REGIONID
               AND O.ADMINID = P_ADMINID_1
               ORDER BY 2,1;*/

  CURSOR C_REGION_DEFAULT (P_ADMINID ADMIN_DIM.ADMINID%TYPE)
  IS
  SELECT ORG_NODEID
  FROM (WITH ORG_HIER AS (SELECT
               ORG_ID,
               ORG_NAME,
               ORG_PARENT_ID,
               ORG_LEVEL,
               ORG_PATH
               FROM org_hierarchy
               WHERE ORG_ID = i_Logged_In_Jasper_Org_ID
             )
             SELECT DISTINCT O.LEVEL3_JASPER_ORGID AS ORG_NODEID,
                             O.LEVEL3_ELEMENT_NAME AS ORG_NODE_NAME
             FROM ORG_NODE_DIM O,ORG_HIER H
             WHERE H.ORG_LEVEL = 1
               AND O.LEVEL1_JASPER_ORGID = H.ORG_ID
               AND O.ADMINID = P_ADMINID
             UNION ALL
             SELECT DISTINCT O.LEVEL3_JASPER_ORGID AS ORG_NODEID,
                             O.LEVEL3_ELEMENT_NAME AS ORG_NODE_NAME
             FROM ORG_NODE_DIM O,ORG_HIER H
             WHERE H.ORG_LEVEL = 2
               AND O.LEVEL2_JASPER_ORGID = H.ORG_ID
               AND O.ADMINID = P_ADMINID
             UNION ALL
             SELECT DISTINCT O.LEVEL3_JASPER_ORGID AS ORG_NODEID,
                             O.LEVEL3_ELEMENT_NAME AS ORG_NODE_NAME
             FROM ORG_NODE_DIM O,ORG_HIER H
             WHERE H.ORG_LEVEL = 3
               AND O.LEVEL3_JASPER_ORGID = H.ORG_ID
               AND O.ADMINID = P_ADMINID
              UNION ALL
             SELECT DISTINCT O.LEVEL3_JASPER_ORGID AS ORG_NODEID,
                             O.LEVEL3_ELEMENT_NAME AS ORG_NODE_NAME
             FROM ORG_NODE_DIM O,ORG_HIER H
             WHERE H.ORG_LEVEL = 4
               AND O.LEVEL4_JASPER_ORGID = H.ORG_ID
               AND O.ADMINID = P_ADMINID
               ORDER BY 2,1)
               WHERE ROWNUM =1;


BEGIN

  IF i_Admin_Id = '-99' THEN
    SELECT ADMINID INTO V_ADMINID FROM ADMIN_DIM WHERE CURRENT_ADMIN = 'Y';

    FOR R_REGION_DEFAULT IN C_REGION_DEFAULT(V_ADMINID)
    LOOP
      V_SCHOOL_IDS := R_REGION_DEFAULT.ORG_NODEID;
    END LOOP;

  ELSE
    V_ADMINID := i_Admin_Id;
    V_SCHOOL_IDS:= i_School_Ids;
    
  END IF;

  FOR R_GET_GRADE IN C_GET_GRADE(V_ADMINID,V_SCHOOL_IDS)
    LOOP
      t_PRS_PGT_GLOBAL_TEMP_OBJ := PRS_PGT_GLOBAL_TEMP_OBJ();
      t_PRS_PGT_GLOBAL_TEMP_OBJ.vc1 := R_GET_GRADE.GRADEID;
      t_PRS_PGT_GLOBAL_TEMP_OBJ.vc2 := R_GET_GRADE.GRADE_NAME;
      t_PRS_PGT_GLOBAL_TEMP_OBJ.vc3 := R_GET_GRADE.GRADE_SEQ;

      t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ.EXTEND(1);
      t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ(t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ.COUNT):= t_PRS_PGT_GLOBAL_TEMP_OBJ;
   END LOOP;
   
   IF t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ.COUNT = 0  THEN
            t_PRS_PGT_GLOBAL_TEMP_OBJ := PRS_PGT_GLOBAL_TEMP_OBJ();
            t_PRS_PGT_GLOBAL_TEMP_OBJ.vc1 := -2;
            t_PRS_PGT_GLOBAL_TEMP_OBJ.vc2 := 'None Available';
            t_PRS_PGT_GLOBAL_TEMP_OBJ.vc3 := -2;

            t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ.EXTEND(1);
            t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ(t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ.COUNT):= t_PRS_PGT_GLOBAL_TEMP_OBJ;
   END IF;
RETURN t_PRS_COLL_PGT_GLOBAL_TEMP_OBJ;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END SF_GET_GRADE_MULTICAMPUS;
/
